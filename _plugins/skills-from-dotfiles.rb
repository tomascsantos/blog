#!/usr/bin/env ruby
#
# Publish agent skills from the dotfiles repo as pages under /skills/<name>/.
#
# _data/skills.yml lists which skills to publish and their example pages. Each
# SKILL.md is read out of git in the dotfiles checkout (`skills:` in
# _config.yml; SKILLS_REPO / SKILLS_REF override), so the site shows whatever
# is committed there. Ref "working-tree" previews uncommitted edits instead.

require "fileutils"
require "open3"

module Skills
  # The raw SKILL.md, served next to its page so it can be curl'd into place.
  class RawFile < Jekyll::StaticFile
    def initialize(site, dir, name, content)
      super(site, site.source, dir, name)
      @content = content
    end

    def write(dest)
      path = destination(dest)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, @content)
      true
    end

    def mtime
      0
    end
  end

  class Generator < Jekyll::Generator
    safe true

    def generate(site)
      entries = site.data["skills"] || []
      return if entries.empty?

      config = site.config["skills"] || {}
      repo = File.expand_path(ENV["SKILLS_REPO"] || config["repo"] || "~/dotfiles")
      ref = ENV["SKILLS_REF"] || config["ref"] || "HEAD"
      dir = config["dir"] || ".agents/skills"

      unless File.exist?(File.join(repo, ".git"))
        Jekyll.logger.warn "Skills:", "no git checkout at #{repo}; skipping skill pages"
        return
      end

      entries.each do |entry|
        name = entry["name"]
        path = "#{dir}/#{name}/SKILL.md"
        raw = ref == "working-tree" ? File.read(File.join(repo, path)) : git(repo, "show", "#{ref}:#{path}")
        meta, body = split_front_matter(raw)
        commit, date = git(repo, "log", "-1", "--format=%h %cs", ref == "working-tree" ? "HEAD" : ref, "--", path).split
        dirty = ref == "working-tree" && !system("git", "-C", repo, "diff", "--quiet", "HEAD", "--", path)

        url_dir = "skills/#{name}"
        page = Jekyll::PageWithoutAFile.new(site, site.source, url_dir, "index.md")
        page.content = body
        page.data.merge!(
          "layout" => "skill",
          "title" => meta["name"] || name,
          "description" => meta["description"],
          "render_with_liquid" => false,
          "skill" => {
            "commit" => commit,
            "date" => date,
            "dirty" => dirty,
            "raw_url" => "/#{url_dir}/SKILL.md",
            "examples" => entry["examples"] || []
          }
        )
        site.pages << page
        site.static_files << RawFile.new(site, url_dir, "SKILL.md", raw)
        Jekyll.logger.info "Skills:", "#{name} @ #{commit}#{dirty ? ' + uncommitted edits' : ''}"
      end
    end

    private

    def git(repo, *args)
      out, err, status = Open3.capture3("git", "-C", repo, *args)
      raise "Skills: git #{args.join(' ')} failed in #{repo}: #{err}" unless status.success?

      out
    end

    def split_front_matter(raw)
      match = raw.match(Jekyll::Document::YAML_FRONT_MATTER_REGEXP)
      return [{}, raw] unless match

      [SafeYAML.load(match[1]) || {}, match.post_match]
    end
  end
end

---
icon: fas fa-wand-magic-sparkles
order: 5
---

Agent skills I use every day, published straight from my dotfiles.

{% assign skills = site.pages | where: "layout", "skill" | sort: "title" %}
{% for skill in skills %}
<div class="mt-4">
  <h4 data-toc-skip><a href="{{ skill.url | relative_url }}">{{ skill.title }}</a></h4>
  <p class="mb-1">{{ skill.description }}</p>
  <small class="text-muted">
    Updated {{ skill.skill.date }}
    {%- if skill.skill.examples.size > 0 %} · with example{% endif %}
  </small>
</div>
{% endfor %}

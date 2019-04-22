require "extensions/views"

activate :views
activate :directory_indexes

page "/articles", layout: "application"
page "CNAME", layout: false
page "/feed.xml", layout: false

set :relative_links, true
set :css_dir, 'assets/stylesheets'
set :js_dir, 'assets/javascripts'
set :images_dir, 'assets/images'
set :fonts_dir, 'assets/fonts'
set :layout, 'layouts/application'

configure :build do
  # Relative assets needed to deploy to Github Pages
  activate :relative_assets
end

activate :deploy do |deploy|
  deploy.build_before = true
  deploy.deploy_method = :git
end

activate :blog do |blog|
  blog.name = "blog"
  blog.prefix = "articles"
  blog.permalink = "{title}.html"
  blog.tag_template = "tag.html"
  blog.layout = "article_layout"
end

activate :disqus do |disqus|
  disqus.shortname = "gjaldon"
end

activate :syntax

activate :livereload

helpers do
  def nav_link(link_text, page_url, options = {})
    options[:class] ||= ""
    if current_page.url.length > 1
      current_url = current_page.url.chop
    else
      current_url = current_page.url
    end
    options[:class] << " active" if page_url == current_url
    link_to(link_text, page_url, options)
  end
end

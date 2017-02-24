# encoding: utf-8

Gem::Specification.new do |s|
  s.name = 'sitemap_generator'
  s.version = File.read('VERSION').chomp
  s.platform = Gem::Platform::RUBY
  s.authors = ['Karl Varga']
  s.email = 'kjvarga@gmail.com'
  s.homepage = 'http://github.com/kjvarga/sitemap_generator'
  s.summary = 'Easily generate XML Sitemaps'
  s.description = 'SitemapGenerator is a framework-agnostic XML Sitemap generator written in Ruby with automatic Rails integration.  It supports Video, News, Image, Mobile, PageMap and Alternate Links sitemap extensions and includes Rake tasks for managing your sitemaps, as well as many other great features.'
  s.license = 'MIT'
  s.add_dependency 'builder', '~> 3.0'
  s.add_development_dependency 'fog-aws', '~> 1.2'
  s.add_development_dependency 'nokogiri', '~> 1.6'
  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'webmock', '~> 2.3'
  s.add_development_dependency 'rake', '~> 12'
  s.files = Dir.glob('{lib,rails,templates}/**/*') + %w(
    CHANGES.md
    MIT-LICENSE
    README.md
    sitemap_generator.gemspec
    VERSION
  )
end

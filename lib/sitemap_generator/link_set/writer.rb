require File.dirname(__FILE__) + '/helper'

module SitemapGenerator
  module LinkSet
    module Writer
      include SitemapGenerator::Helper
      include ActionView::Helpers::NumberHelper

      attr_accessor :default_host, :yahoo_app_id, :links
      attr_accessor :sitemaps, :max_entries, :link_count
      attr_accessor :host

      alias :sitemap_files :sitemaps

      # Create new link set instance.
      #
      # Optional <tt>host</tt> is the host symbol.  Defines the subdirectory
      # in which to place sitemap files.  If nil, no subdirectory is used.
      def initialize(host)
        self.host        = host.to_s
        self.links       = []
        self.sitemaps    = []
        self.max_entries = SitemapGenerator::MAX_ENTRIES
        self.link_count  = 0
      end

      # Add default links to sitemap files.
      def add_default_links
        add_link Link.generate('/', :lastmod => Time.now, :changefreq => 'always', :priority => 1.0)
        add_link Link.generate("/#{index_file}", :lastmod => Time.now, :changefreq => 'always', :priority => 1.0)
      end

      # Add links from mapper to sitemap files.
      def add_link(link)
        write_upcoming if enough_links?
        links.push link
        self.link_count += 1
      end

      # Write links to sitemap file.
      def write
        write_pending
      end

      # Write links to upcoming sitemap file.
      def write_upcoming
        write_sitemap(upcoming_file)
      end

      # Write pending links to sitemap, write index file if needed.
      def write_pending
        write_upcoming
        write_index
      end

      # Write links to sitemap file.
      def write_sitemap(file = upcoming_file)
        buffer = ""
        xml = Builder::XmlMarkup.new(:target => buffer)
        eval(File.read(SitemapGenerator.templates[:sitemap_xml]), binding)
        filename = File.join(RAILS_ROOT, "tmp", file)
        write_file(filename, buffer)
        show_progress("Sitemap", filename, buffer) if verbose
        links.clear
        sitemaps.push filename
      end

      # Write sitemap links to sitemap index file.
      def write_index
        buffer = ""
        xml = Builder::XmlMarkup.new(:target => buffer)
        eval(File.read(SitemapGenerator.templates[:sitemap_index]), binding)
        filename = File.join(RAILS_ROOT, "public", index_file)
        write_file(filename, buffer)
        show_progress("Sitemap Index", filename, buffer) if verbose
        links.clear
        sitemaps.clear
      end

      # Return sitemap or sitemap index main name.
      def index_file
        "sitemap_index.xml.gz"
      end

      # Return upcoming sitemap name with index.
      def upcoming_file
        "sitemap#{upcoming_index}.xml.gz" unless enough_sitemaps?
      end

      # Return upcoming sitemap index, first is 1.
      def upcoming_index
        sitemaps.length + 1 unless enough_sitemaps?
      end

      # Return true if upcoming is first sitemap.
      def first_sitemap?
        sitemaps.empty?
      end

      # Return true if sitemap index needed.
      def multiple_sitemaps?
        !first_sitemap?
      end

      # Return true if more sitemaps can be added.
      def more_sitemaps?
        sitemaps.length < max_entries
      end

      # Return true if no sitemaps can be added.
      def enough_sitemaps?
        !more_sitemaps?
      end

      # Return true if this is the first link added.
      def first_link?
        links.empty? && first_sitemap?
      end

      # Return true if more links can be added.
      def more_links?
        links.length < max_entries
      end

      # Return true if no further links can be added.
      def enough_links?
        !more_links?
      end

      # Commit buffer to gzipped file.
      def write_file(name, buffer)
        Zlib::GzipWriter.open(name) { |gz| gz.write buffer }
      end

      # Report progress line.
      def show_progress(title, filename, buffer)
        puts "+ #{filename}"
        puts "** #{title} too big! The uncompressed size exceeds 10Mb" if buffer.size > 10.megabytes
      end

      # Copy templates/sitemap.rb to config if not there yet.
      def install_sitemap_rb
        if File.exist?(File.join(RAILS_ROOT, 'config/sitemap.rb'))
          puts "already exists: config/sitemap.rb, file not copied"
        else
          FileUtils.cp(SitemapGenerator.templates[:sitemap_sample], File.join(RAILS_ROOT, 'config/sitemap.rb'))
          puts "created: config/sitemap.rb"
        end
      end

      # Remove config/sitemap.rb if exists.
      def uninstall_sitemap_rb
        if File.exist?(File.join(RAILS_ROOT, 'config/sitemap.rb'))
          File.rm(File.join(RAILS_ROOT, 'config/sitemap.rb'))
        end
      end

      # Clean sitemap files in output directory.
      def clean_files
        FileUtils.rm(Dir[File.join(RAILS_ROOT, 'public/sitemap*.xml.gz')])
      end

      # Ping search engines passing sitemap location.
      def ping_search_engines
        super index_file
      end

      # Create sitemap files in output directory.
      def create_files(verbose = true)
        start_time = Time.now
        load_sitemap_rb
        write
        stop_time = Time.now
        puts "Sitemap stats: #{number_with_delimiter(SitemapGenerator::Sitemap.link_count)} links, " + ("%dm%02ds" % (stop_time - start_time).divmod(60)) if verbose
      end
    end
  end
end

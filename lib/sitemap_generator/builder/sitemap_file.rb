require 'zlib'
require 'action_view' # for number_to_human_size
require 'fileutils'

module SitemapGenerator
  module Builder
    #
    # General Usage:
    #
    #   sitemap = SitemapFile.new(:location => SitemapLocation.new(...))
    #   sitemap.add('/', { ... })    <- add a link to the sitemap
    #   sitemap.finalize!            <- write the sitemap file and freeze the object to protect it from further modification
    #
    class SitemapFile
      include ActionView::Helpers::NumberHelper
      include ActionView::Helpers::TextHelper   # Rails 2.2.2 fails with missing 'pluralize' otherwise
      attr_reader :link_count, :filesize, :filename, :location

      # Options:
      #
      # <tt>location</tt> a SitemapGenerator::SitemapLocation instance
      #
      # <tt>filename</tt> a symbol giving the base of the sitemap fileaname.  Default: :sitemap
      #
      # <tt>namer</tt> (optional) if provided is used to get the next sitemap filename, overriding :filename
      def initialize(opts={})
        @options = [:location, :filename, :namer]
        SitemapGenerator::Utilities.assert_valid_keys(opts, @options)

        @location = opts.delete(:location) || SitemapGenerator::SitemapLocation.new
        @namer = opts.delete(:namer) || new_namer(opts.delete(:filename))
        @filename = @location[:filename] = @namer.next
        @link_count = 0
        @xml_content = '' # XML urlset content
        @xml_wrapper_start = <<-HTML
          <?xml version="1.0" encoding="UTF-8"?>
            <urlset
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"
              xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
                http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"
              xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
              xmlns:video="http://www.google.com/schemas/sitemap-video/1.1"
              xmlns:geo="http://www.google.com/geo/schemas/sitemap/1.0"
            >
        HTML
        @xml_wrapper_start.gsub!(/\s+/, ' ').gsub!(/ *> */, '>').strip!
        @xml_wrapper_end   = %q[</urlset>]
        @filesize = bytesize(@xml_wrapper_start) + bytesize(@xml_wrapper_end)
      end

      def lastmod
        File.mtime(path) rescue nil
      end

      def empty?
        @link_count == 0
      end

      # Return a boolean indicating whether the sitemap file can fit another link
      # of <tt>bytes</tt> bytes in size.  You can also pass a string and the
      # bytesize will be calculated for you.
      def file_can_fit?(bytes)
        bytes = bytes.is_a?(String) ? bytesize(bytes) : bytes
        (@filesize + bytes) < SitemapGenerator::MAX_SITEMAP_FILESIZE && @link_count < SitemapGenerator::MAX_SITEMAP_LINKS
      end

      # Add a link to the sitemap file.
      #
      # If a link cannot be added, for example if the file is too large or the link
      # limit has been reached, a SitemapGenerator::SitemapFullError exception is raised
      # and the sitemap is finalized.
      #
      # If the Sitemap has already been finalized a SitemapGenerator::SitemapFinalizedError
      # exception is raised.
      #
      # Return the new link count.
      #
      # Call with:
      #   sitemap_url - a SitemapUrl instance
      #   sitemap, options - a Sitemap instance and options hash
      #   path, options - a path for the URL and options hash
      def add(link, options={})
        raise SitemapGenerator::SitemapFinalizedError if finalized?
        xml = (link.is_a?(SitemapUrl) ? link : SitemapUrl.new(link, options)).to_xml
        raise SitemapGenerator::SitemapFullError if !file_can_fit?(xml)

        # Add the XML to the sitemap
        @xml_content << xml
        @filesize += bytesize(xml)
        @link_count += 1
      end

      # Write out the Sitemap file and freeze this object.
      #
      # All the xml content in the instance is cleared, but attributes like
      # <tt>filesize</tt> are still available.
      #
      # A SitemapGenerator::SitemapFinalizedError exception is raised if the Sitemap
      # has already been finalized
      def finalize!
        raise SitemapGenerator::SitemapFinalizedError if finalized?

        # Ensure that the directory exists
        dir = @location.directory
        path = @location.path
        if !File.exists?(dir)
          FileUtils.mkdir_p(dir)
        elsif !File.directory?(dir)
          raise SitemapError.new("#{dir} should be a directory!")
        end

        open(path, 'wb') do |file|
          gz = Zlib::GzipWriter.new(file)
          gz.write @xml_wrapper_start
          gz.write @xml_content
          gz.write @xml_wrapper_end
          gz.close
        end
        @xml_content = @xml_wrapper_start = @xml_wrapper_end = ''
        freeze
      end

      def finalized?
        frozen?
      end

      # Return a new instance of the sitemap file with the same options, and the next name in the sequence.
      def next
        self.class.new(@options.inject({}) do |memo, key|
          memo[key] = instance_variable_get("@#{key}".to_sym)
          memo
        end)
      end

      # Return a summary string
      def summary(opts={})
        uncompressed_size = number_to_human_size(@filesize) rescue "#{@filesize / 8} KB"
        compressed_size =   number_to_human_size(@location.filesize) rescue "#{@location.filesize / 8} KB"
        "+ #{'%-21s' % @location.path_in_public} #{'%13s' % @link_count} links / #{'%10s' % uncompressed_size} / #{'%10s' % compressed_size} gzipped"
      end

      # Create a new namer given a filename base and set the filename of this sitemap from it.
      # It is a bit confusing because the setter takes a filename base whereas the getter
      # returns a full filename including extension.
      def filename=(base)
        @namer = new_namer(base)
        @filename = @location[:filename] = @namer.next
      end

      protected

      # Return a new namer given a filename base and set the filename of this sitemap from it.
      # Default filename base is 'sitemap'.
      def new_namer(base=nil)
        SitemapGenerator::SitemapNamer.new(base ||= :sitemap)
      end

      # Return the bytesize length of the string.  Ruby 1.8.6 compatible.
      def bytesize(string)
        string.respond_to?(:bytesize) ? string.bytesize : string.length
      end
    end
  end
end
module SitemapGenerator
  # A class for generating sitemap filenames.
  #
  # The SimpleNamer uses the same namer instance for the sitemap index and the sitemaps.
  # If no index is needed, the first sitemap gets the first name.  However, if
  # an index is needed, the index gets the first name.
  #
  # A typical sequence would looks like this:
  #   * sitemap.xml.gz
  #   * sitemap1.xml.gz
  #   * sitemap2.xml.gz
  #   * sitemap3.xml.gz
  #   * ...
  #
  # Arguments:
  #   base - string or symbol that forms the base of the generated filename e.g.
  #          if `:geo` files are generated like `geo.xml.gz`, `geo1.xml.gz`, `geo2.xml.gz` etc.
  #
  # Options:
  #   :extension - Default: '.xml.gz'. File extension to append.
  #   :start     - Default: 1. Numerical index at which to start counting.
  #   :zero      - Default: nil.  A string or number that is appended to +base+
  #                to create the first name in the sequence.  So setting this
  #                to '_index' would produce 'sitemap_index.xml.gz' as
  #                the first name.  Thereafter, the numerical index defined by +start+
  #                is used, and subsequent names would be 'sitemap1.xml.gz', 'sitemap2.xml.gz', etc.
  #                In these examples the `base` string is assumed to be 'sitemap'.
  #   :compress  - Default: true.  The LinkSet compress setting.  If `false` any `.gz` extension is
  #                stripped from the filename.  If `:all_but_first`, only the `.gz` extension of the first
  #                filename is stripped off.  If `true` the extensions are left unchanged.
  class SimpleNamer < SitemapNamer
    def initialize(base, options={})
      super_options = SitemapGenerator::Utilities.reverse_merge(options,
        :zero => nil # identifies the marker for the start of the series
      )
      super(base, super_options)
    end

    def to_s
      extension = @options[:extension]

      # Strip the `.gz` from the extension if we aren't compressing this file.
      if (start? && @options[:compress] == :all_but_first) ||
         (@options[:compress] == false)
        extension.gsub(/\.gz/, '')
      end

      "#{@base}#{@count}#{extension}"
    end

    # Reset to the first name
    def reset
      @count = @options[:zero]
    end

    # True if on the first name
    def start?
      @count == @options[:zero]
    end

    # Return this instance set to the next name
    def next
      if start?
        @count = @options[:start]
      else
        @count += 1
      end
      self
    end

    # Return this instance set to the previous name
    def previous
      raise NameError, "Already at the start of the series" if start?
      if @count <= @options[:start]
        @count = @options[:zero]
      else
        @count -= 1
      end
      self
    end
  end
end

require 'rack/utils'
require 'cgi'
require 'embed_html'

module Rack
  class Embed
    def initialize(app, opts = {})
      @app = app
      @encode_param = opts[:encode_param]
      @mime_types = opts[:mime_types] || %w(application/xhtml+xml text/html)
    end

    def call(env)
      ua = env['HTTP_USER_AGENT']

      # Replace this with something more sophisticated
      # Supported according to http://en.wikipedia.org/wiki/Data_URI_scheme
      if !ua || ua !~ /WebKit|Gecko|Opera|Konqueror|MSIE 8.0|CFNetwork/
        return @app.call(env)
      end

      # only encode if the parameter exists
      request = Rack::Request.new(env)
      return @app.call(env) unless request.params.key?(@encode_param)
      
      original_env = env.clone
      response = @app.call(env)
      return response if !applies_to?(response)
      

      status, header, body = response
      body = EmbedHtml::Embeder.new(body.first).process
      header['Content-Length'] = Rack::Utils.bytesize(body).to_s

      
      [status, header, [body]]
    rescue Exception => ex
      env['rack.errors'].write("#{ex.message}\n") if env['rack.errors']
      [500, {}, ex.message]
    end

    private

    def applies_to?(response)
      status, header, body = response

      # Some stati don't have to be processed
      return false if [301, 302, 303, 307].include?(status)

      # Check mime type
      return false if !@mime_types.include?(content_type(header))

      response[2] = [body = join_body(body)]

      # Something to embed?
      body =~ /<img[^>]+src=/
    end

    def content_type(header)
      header['Content-Type'] && header['Content-Type'].split(';').first.strip
    end

    # Join response body
    def join_body(body)
      parts = ''
      body.each { |part| parts << part }
      parts
    end
  end
end

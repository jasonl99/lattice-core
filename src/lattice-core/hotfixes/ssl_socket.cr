abstract class OpenSSL::SSL::Socket
  class Server < Socket
    def initialize(io, context : Context::Server = Context::Server.new, sync_close : Bool = false)
      super(io, context, sync_close)

      ret = LibSSL.ssl_accept(@ssl)
      unless ret == 1
        io.close if sync_close   # this is the hotfix
        raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_accept")
      end
    end
end

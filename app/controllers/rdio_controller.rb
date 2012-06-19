require 'oauth'
require 'json'

class RdioController < ApplicationController
    
    CONSUMER_KEY = "5bfedcawpujawzvntkhxvksr"
    CONSUMER_SECRET = "pgcp5hNkY5"
    layout 'none'

    def env
        render :text => request.local?
    end
    
    def test
        set_playback_token
    end

    #####################    
    private
    
    def set_playback_token
        if request.local?
            @playback_token = 'GAlNi78J_____zlyYWs5ZG02N2pkaHlhcWsyOWJtYjkyN2xvY2FsaG9zdEbwl7EHvbylWSWFWYMZwfc='
        else
            consumer = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET,
                                   :site => "http://api.rdio.com",
                                   :request_token_path => "/oauth/request_token",
                                   :authorize_path => "/oauth/authorize",
                                   :access_token_path => "/oauth/access_token",
                                   :http_method => :post)
            access_token = OAuth::AccessToken.new consumer
            res = access_token.post('http://api.rdio.com/1/', 'method'=>'getPlaybackToken')
            res_hash = JSON.parse(res.body)
            if res_hash['status'] == 'ok'
                @playback_token = res_hash['result']
            else
                @playback_token = 'error'
            end
        end
    end


end

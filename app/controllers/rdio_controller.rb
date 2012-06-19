require 'oauth'
require 'json'

class RdioController < ApplicationController
    
    CONSUMER_KEY = "5bfedcawpujawzvntkhxvksr"
    CONSUMER_SECRET = "pgcp5hNkY5"
    RDIO_API_URL = 'http://api.rdio.com/1/'
    
    layout 'none'

    def env
        render :text => request.local?
    end
    
    def test
        set_playback_token
    end

    def activity_stream
        access_token = get_access_token    
        res = access_token.post(RDIO_API_URL, 
            'method'=>'getActivityStream', 
            'user'=>'swetonic', 
            'scope'=>'user')
        res_hash = JSON.parse(res.body)
        render :json => res_hash
    end

    #####################    
    private
    
    def get_access_token
        consumer = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET,
                               :site => "http://api.rdio.com",
                               :request_token_path => "/oauth/request_token",
                               :authorize_path => "/oauth/authorize",
                               :access_token_path => "/oauth/access_token",
                               :http_method => :post)
        OAuth::AccessToken.new consumer
    end
    
    def set_playback_token
        if request.local?
            @playback_token = 'GAlNi78J_____zlyYWs5ZG02N2pkaHlhcWsyOWJtYjkyN2xvY2FsaG9zdEbwl7EHvbylWSWFWYMZwfc='
        else
            access_token = get_access_token
            res = access_token.post(RDIO_API_URL, 'method'=>'getPlaybackToken')
            res_hash = JSON.parse(res.body)
            if res_hash['status'] == 'ok'
                @playback_token = res_hash['result']
            else
                @playback_token = 'error'
            end
        end
    end


end

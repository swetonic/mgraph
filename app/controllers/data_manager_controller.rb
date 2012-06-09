require 'uri'
require 'net/http'

class DataManagerController < ApplicationController
    API_KEY = 'rk4zzd4n8kr7j3td4vmjvduk'
    SHARED_SECRET = 'AQ3sKz9ugz'
    MAX_NODES = 4
    
    
    def collaborators3
        @collaborator_data = call_api(params['name'])
    end

    def collaborators
        if not params.has_key?('name')
            @name = "miles davis"
        else
            @name = params['name']
        end
        @max_nodes = MAX_NODES
        if params.has_key?('max_nodes')
            @max_nodes = params['max_nodes'].to_i
        end
        #collaborators_json
    end
    
    def collaborators_json
        response = JSON.parse(call_info_api(params['name']))
        if response['status'] == 'error'
            render :json => {:status => 'error', :text => "No information for #{params['name']}"}
        else
            max_nodes = MAX_NODES
            if params.has_key?('max_nodes')
                max_nodes = params['max_nodes'].to_i
            end
            unique_names = {}
            collaborator_hash = {}
            puts response
            if response['name']['collaboratorWithUri'] != nil
                collaborator_hash = build_collaborators(params['name'], unique_names, max_nodes, collaborator_hash, 
                    response['name']['collaboratorWithUri'])
            end
            render :json => collaborator_hash.to_json
        end
    end
    
    private
    def get_collaborators(url)
        return [] if url.nil?
        
        collaborators = []
        url += '&sig=' + generate_sig
        response = Net::HTTP.get_response( URI.parse( url ) )

        while not response.body.index("Service Unavailable").nil?
            puts "************************"
            puts "sleeping"
            sleep(1)
            response = Net::HTTP.get_response( URI.parse( url ) )
        end
        
        collab_with = JSON.parse(response.body)['collaboratorWith'].each do |collab|
            collaborators << collab['name'].downcase
        end
        collaborators
    end

    def build_collaborators(name, unique_names, max_nodes, collaborator_hash, url)
        name.downcase!
        collabs = get_collaborators(url)
        collaborator_hash[name] = collabs
        collabs.each do |collab|
            collab.downcase!
            if unique_names.has_key?(collab)
                next
            end
            unique_names[collab] = 1
            if unique_names.size >= max_nodes
                return collaborator_hash
            else
                response = JSON.parse(call_info_api(collab))
                return build_collaborators(collab, unique_names, max_nodes, collaborator_hash, response['name']['collaboratorWithUri'])
            end
        end
        return collaborator_hash
    end
    
    def generate_sig
        Digest::MD5.hexdigest(API_KEY + SHARED_SECRET + Time.now.to_i.to_s)
    end
    
    def call_info_api(name)
        url = "http://api.rovicorp.com/data/v1/name/info?name="
        url += name.gsub(' ', '+').gsub('"', "%34")
        url += "&country=US&language=en&format=json&country=US&language=en&apikey="
        url += API_KEY
        url += "&sig=" + generate_sig
        response = Net::HTTP.get_response( URI.parse( url ) )
        
        while not response.body.index("Service Unavailable").nil?
            puts "*****************************"
            puts "sleeping"
            sleep(1)
            response = Net::HTTP.get_response( URI.parse( url ) )
        end
        
        return response.body
    end

end

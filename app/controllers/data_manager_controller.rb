require 'uri'
require 'net/http'

class DataManagerController < ApplicationController
    API_KEY = 'rk4zzd4n8kr7j3td4vmjvduk'
    SHARED_SECRET = 'AQ3sKz9ugz'
    MAX_NODES = 5
    
    NOTES = ['A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#']
    NOTES_WITH_FLATS = ['A', 'Bb', 'B', 'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab']
    ENHARMONIC_EQUIVALENTS = {
        'A#' => 'Bb', 'Bb' => 'A#',
        'C#' => 'Db', 'Db' => 'C#',
        'D#' => 'Eb', 'Eb' => 'D#',
        'F#' => 'Gb', 'Gb' => 'F#',
        'G#' => 'Ab', 'Ab' => 'G#',
        'B' => 'Cb',
        'E' => 'Fb'
    }
    
    TRIADS = {
        'major' => [0, 4, 7], 
        'minor' => [0, 3, 7], 
        'augmented' => [0, 4, 8],
        'diminished' => [0, 3, 6]
    }

    SEVENTH_CHORDS = {
        'major 7' => [0, 4, 7, 11], 
        'minor 7' => [0, 3, 7, 10], 
        'dominant 7' => [0, 4, 7, 10],
        'diminished 7' => [0, 3, 6, 9]
    }

    NOTE_REPLACE_MAP = {
        'C diminished 7' => {'F#'=>1, 'D#'=>1},
        'C minor 7' => {'A#'=>1, 'D#'=>1},
        'C dominant 7' => {'A#'=>1},
        'F diminished 7' => {'G#'=>1},
        'F minor 7' => {'G#'=>1, 'D#'=>1},
        'F dominant 7' => {'D#'=>1},
    }
    
    def chords
        if not params.key?('root')
            @root = "A"
        else
            @root = params['root']
        end
    end
    
    def chords_json
        if not params.key?('root')
            root = "A"
        else
            root = params['root']
        end
        if NOTES.index(root) != nil
            render :json => convert_hash(get_chords(root)).to_json
        else
            render :json => {'error' => "Couldn't find root #{root}"}.to_json
        end
    end
    
    def triads_json
        if not params.key?('root')
            root = "A"
        else
            root = params['root']
        end
        if NOTES.index(root) != nil
            render :json => convert_hash(get_triads(root)).to_json
        else
            render :json => {'error' => "Couldn't find root #{root}"}.to_json
        end
    end

    def coll
        collaborators
    end

    def coll2
        if not params.has_key?('name')
            @name = "miles davis"
        else
            @name = params['name']
        end
    end

    def coll_json
        coll_array = []
        coll_hash = collaborators_hash        
        val = 1000
        all_names = {}
        
        coll_hash.keys.each do |name|
            coll_array << {"imports" => coll_hash[name], "name" => name, "size" => val}
            coll_hash[name].each do |name|
                all_names[name] = 1
            end
            val += 10
        end
        
        all_names.keys.each do |name|
            if not coll_hash.key?(name)
                coll_array << {"imports" => [], "name" => name, "size" => val};
            end
            val += 10
        end
        
        render :json => coll_array
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
    end
  
    def collaborators_json
        render :json => collaborators_hash
    end

    ###########################################    
    private

    #convert hash to conform to d3's array format
    def convert_hash(hash)
        val = 1000
        return_array = []
        
        hash.keys.each do |name|
            return_array << {"imports" => hash[name], "name" => name, "size" => val}
        end

        all_notes = {}
        return_array = replace_notes(return_array)
        return_array.each do |hash|
            hash['imports'].each do |note|
                all_notes[note] = 1
            end
        end
        
        all_notes.keys.each do |note|
            return_array << {"imports" => [], "name" => note, "size" => val}
        end
        return_array
    end
    
    #lookup chords/triads to see if they need enharmonic equivalents
    def replace_notes(array)
        array.each do |hash|
            if NOTE_REPLACE_MAP.key?(hash['name'])
                should_replace = NOTE_REPLACE_MAP[hash['name']]
                hash['imports'].each_with_index do |note,idx|
                    if should_replace.key?(note)
                        hash['imports'][idx] = ENHARMONIC_EQUIVALENTS[note]
                    end
                end
            end
        end
        array
    end
    
    def get_chords(root)
        triads = {}
        idx = NOTES.index(root)
        if idx != -1
            SEVENTH_CHORDS.keys.each do |triad_type|
                notes = []
                SEVENTH_CHORDS[triad_type].each do |offset|
                    notes << NOTES[(idx+offset)%12]
                end
                triads[root + " " + triad_type] = notes
            end
        end
        triads
    end

    def get_triads(root)
        triads = {}
        idx = NOTES.index(root)
        if idx != -1
            TRIADS.keys.each do |triad_type|
                notes = []
                TRIADS[triad_type].each do |offset|
                    notes << NOTES[(idx+offset)%12]
                end
                triads[root + " " + triad_type] = notes
            end
        end
        triads
    end
    
    def collaborators_hash
        response = JSON.parse(call_info_api(params['name']))
        if response['status'] == 'error'
            {:status => 'error', :text => "No information for #{params['name']}"}
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
            collaborator_hash
        end
    end

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
        sleep(0.2)
        return response.body
    end

end

require 'uri'
require 'net/http'
require 'mongo'

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

    def mongo_save
        mcoll.insert({"yo" => "tim", "dude" => 1.2})
        render :text => "done"
    end
    
    def mongo_search
      rows = mcoll.find("name" => "tim")      
      #rows = data_coll.find("_id" => BSON::ObjectId("4fd91bc39e97f8a72aa41ed1"))
      #row = data_coll.find_one
      output = ""
      rows.each do |row|
          output += row.inspect + "<br>"
      end
      render :text => output
    end
    
    def mongo
      output = ''
      mcoll.find.each do |data|
        unless data["name"].nil?
            output += data["name"].to_s + "<br>"
        end
      end
      render :text => output
    end
    
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
        #get collaborators for params['name']
        name = params['name']
        
        #then make max_nodes lookups for more collaborators
        max_nodes = params['max_nodes'].to_i
        
        collaborator_hash = {}
        all_names = {}
        collabs = get_collaborators(name)
        collaborator_hash[name] = collabs
        collab_count = 0
        collabs.each do |collab|
            all_names[collab] = 1
            collaborator_hash[collab] = get_collaborators(collab)
            collaborator_hash[collab].each do |c|
                all_names[c] = 1
            end
            collab_count += 1
            break if collab_count >= max_nodes
        end

        #all_names.keys.each do |name|
        #    if not collaborator_hash.key?(name)
        #        collaborator_hash[name] = []
        #    end
        #end
        
        render :json => collaborator_hash
    end

    def call_api
      render :text => call_info_api(params['name'])
    end
    
    ###########################################    
    private

    ## return the collection used in mongo data store
    def mcoll(collection = "data")
      conn = Mongo::Connection.new
      uri = URI.parse(ENV['MONGOHQ_URL'])
      conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
      puts "***************************************"
      puts ENV['MONGOHQ_URL']
      db = conn.db(uri.path.gsub(/^\//, ''))
      #db = conn.db("mgraph")
      data_coll = db.collection(collection)
      data_coll
    end
    
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
    
    ###################
    def get_collaborators(name)
        #check if name is in mongo db store
        data_coll = mcoll
        rows = data_coll.find("name" => name)      
        if rows.count == 0
            #not in mongo, call rovi
            response = call_info_api(name)
            #store in mongo
            id = data_coll.insert({"name" => name, "raw_data" => JSON.parse(response)})
            doc = data_coll.find({"_id" => id})
            doc = rows.next
        else
            doc = rows.next        
        end
        
        if not doc.has_key?("collaborators")
            #need to fetch the collaborators
            doc['collaborators'] = api_get_collaborators(doc['raw_data']['name']['collaboratorWithUri'])
            data_coll.update({"_id"=>doc["_id"]}, doc)
        end
        doc["collaborators"]
    end

    ########
    ## call rovi to get collaborators
    def api_get_collaborators(url)
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
      response.body
    end

end










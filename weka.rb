
require "weka_command_line.rb"
require "weka_dataset.rb"

set :lock, true

@@modeldir = "model"

class String
  def to_boolean
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: '#{self}'")
  end
end

module Weka
  
  class WekaModel < Ohm::Model 
    
    attribute :date
    attribute :creator
    attribute :weka_algorithm
    attribute :algorithm_params
    attribute :training_dataset_uri
    attribute :prediction_feature
    attribute :independent_features_yaml
    attribute :arff_class_index
    attribute :file
    attribute :predicted_datasets_yaml

    index :weka_algorithm
    index :prediction_feature
    index :training_dataset_uri
    
    attr_accessor :subjectid
    
    def independent_features
      self.independent_features_yaml ? YAML.load(self.independent_features_yaml) : []
    end
    
    def independent_features=(array)
      self.independent_features_yaml = array.to_yaml
    end
    
    def predicted_datasets
      self.predicted_datasets_yaml ? YAML.load(self.predicted_datasets_yaml) : {}
    end
    
    def predicted_datasets=(hash)
      self.predicted_datasets_yaml = hash.to_yaml
    end
    
    def self.check_weka_algorithm(weka_algorithm)
      case weka_algorithm
      when /NaiveBayes/
        return "weka.classifiers.bayes.NaiveBayes"
      when /J48/
        return "weka.classifiers.trees.J48"
      when /RandomForest/
        return "weka.classifiers.trees.RandomForest"
      when /SMOreg/
          return "weka.classifiers.functions.SMOreg"        
      when /SMO/
        return "weka.classifiers.functions.SMO"
      when /M5P/
        return "weka.classifiers.trees.M5P"
      else
        raise OpenTox::BadRequestError.new("weka algorithm nor registered: #{weka_algorithm}")
      end
    end
    
    def find_predicted_model(dataset_uri)
      predicted_datasets[dataset_uri] 
    end
    
    def self.find_model(params)
      p = {}
      params.keys.each do |k|
        key = k.to_s
        if key=="dataset_uri"
          p[:training_dataset_uri] = params[k]
        elsif key=="weka_algorithm"
          p[:weka_algorithm] = WekaModel.check_weka_algorithm(params[k])
        else  
          p[key.to_sym] = params[k]
        end
      end
      #puts p.to_yaml
      LOGGER.debug "searching for existing weka model #{p.inspect}"
      [:splat,:captures].each{|k| p.delete(k)}
      set = Weka::WekaModel.find(p).collect.delete_if{|m| !File.exist?(m.model_file())}
      if (set.size == 0)
        return nil
      else 
        set.collect.last.uri # collect to convert Ohm:set in order to apply .last
      end
    end
    
    def self.feature_type(weka_algorithm)
      case weka_algorithm
      when /M5P|SMOreg/
          return "regression"
      when /NaiveBayes|J48|RandomForest|SMO$/
        return "classification"
      else
        raise OpenTox::BadRequestError.new("weka algorithm nor registered: #{weka_algorithm}")
      end
    end
  
    def self.create(params={}, subjectid=nil)
      params[:weka_algorithm] = check_weka_algorithm(params.delete("weka_algorithm"))
      params[:date] = Time.new
      params[:creator] = AA_SERVER ? OpenTox::Authorization.get_user(subjectid) : "unknown"
      params[:training_dataset_uri] = params.delete("dataset_uri")
      [:splat,:captures].each{|k| params.delete(k)}
      model = super params
      model.subjectid = subjectid
      model
    end
    
    def build(waiting_task=nil)
      
      LOGGER.debug "get dataset as arff #{self.training_dataset_uri}"
      arff_string = OpenTox::RestClientWrapper.get(self.training_dataset_uri,{:accept=>"text/arff"})
      #LOGGER.debug "got arff:\n#{arff_string}"
      self.arff_class_index = -1
      attr_index = 0
      attrs = []
      arff_string.each_line do |s|
        if s =~ /@ATTRIBUTE/
          attrs << s.chomp
          attr_index += 1 
          if s =~ /#{self.prediction_feature}/
            self.arff_class_index = attr_index
          end 
        end
      end
      raise "prediction feature #{prediction_feature} not found in arff-file #{attrs.inspect}" if self.arff_class_index==-1
      LOGGER.debug "class_index #{self.arff_class_index}"
      data_file = File.new(training_arff_file(),"w+")
      data_file.write(arff_string)
      data_file.close
      LOGGER.debug "saved to "+data_file.path
      raise "no id" if self.id==nil
      WekaCommandLine::build_model(self.weka_algorithm,data_file.path,self.arff_class_index,self.model_file())
      raise "weka model building failed" unless File.exist?(self.model_file())
      self.save
      File.delete(data_file.path)
    end
    
    def model_file
      @@modeldir+"/"+self.id+".model"
    end
    
    def training_arff_file
      @@modeldir+"/"+self.id+".training.arff"
    end
    
    def test_arff_file
      @@modeldir+"/"+self.id+".test.arff"
    end
    
    def metadata
      value_feature_uri = File.join( uri, "predicted", "value")
      #confidence_feature_uri = File.join( uri, "predicted", "confidence")
      features = [value_feature_uri] #, confidence_feature_uri]
      { DC.title => "#{weka_algorithm} Weka Model",
        DC.creator => creator, 
        OT.trainingDataset => training_dataset_uri, 
        OT.dependentVariables => prediction_feature,
        OT.predictedVariables => features,
        OT.independentVariables => ["n/a"],#independent_features,
        OT.featureDataset => training_dataset_uri,#feature_dataset_uri,
      }
    end
    
    def to_rdf
      s = OpenTox::Serializer::Owl.new
      #LOGGER.debug metadata.to_yaml
      s.add_model(uri,metadata)
      s.to_rdfxml
    end    
    
    def prediction_value_feature
      feature = OpenTox::Feature.new File.join( uri, "predicted", "value")
      feature.add_metadata( {
        RDF.type => [OT.ModelPrediction, 
          (WekaModel::feature_type(self.weka_algorithm)=="classification" ? OT.NominalFeature : OT.NumericFeature) ],
        OT.hasSource => uri,
        DC.creator => uri,
        DC.title => "#{URI.decode(File.basename( prediction_feature ))} prediction",
      })
      feature
    end
    
    def apply(dataset_uri, waiting_task=nil)
      
      test_dataset = OpenTox::Dataset.find(dataset_uri)
      if !test_dataset.features.keys.include?(self.prediction_feature)
        new_test_dataset = OpenTox::Dataset.create(CONFIG[:services]["opentox-dataset"],subjectid)
        test_dataset.compounds.each{|c| new_test_dataset.add_compound(c)}
        test_dataset.features.keys.each do |f|
          m = test_dataset.features[f]
          new_test_dataset.add_feature(f,m)
          test_dataset.compounds.each do |c|
            test_dataset.data_entries[c][f].each do |v|
              new_test_dataset.add(c,f,v,true) if 
                test_dataset.data_entries[c] and test_dataset.data_entries[c][f]
            end if test_dataset.data_entries[c] and test_dataset.data_entries[c][f]
          end
        end
        train_dataset = OpenTox::Dataset.find(self.training_dataset_uri)
        new_test_dataset.add_feature(self.prediction_feature,train_dataset.features[self.prediction_feature])
        new_test_dataset.save
        LOGGER.debug "Created new dataset: #{new_test_dataset.uri}"
        test_dataset = new_test_dataset
        created_modified_test_dataset = true
      else
        created_modified_test_dataset = false 
      end
      LOGGER.debug "get dataset as arff #{dataset_uri}"     
      arff_string = OpenTox::RestClientWrapper.get(test_dataset.uri,{:accept=>"text/arff"})
  
      #LOGGER.debug "got arff:\n#{arff_string}"
      data_file = File.new(test_arff_file(),"w+")
      data_file.write(arff_string)
      data_file.close
      predictions = WekaCommandLine::apply_model(self.weka_algorithm,data_file.path,self.arff_class_index,self.model_file(),
        WekaModel::feature_type(self.weka_algorithm))
      raise "no predictions" unless predictions.size>0
      
      # count duplicates
      num_compounds = {}
      test_dataset.features.keys.each do |f|
        test_dataset.compounds.each do |c|
          if test_dataset.data_entries[c]
            val = test_dataset.data_entries[c][f]
            size = val==nil ? 1 : val.size
            num_compounds[c] = num_compounds[c]==nil ? size : [num_compounds[c],size].max
          else
            num_compounds[c] = 1
          end
        end
      end  
      
      dataset = OpenTox::Dataset.create(CONFIG[:services]["opentox-dataset"],subjectid)
      metadata = { DC.creator => self.uri, OT.hasSource => dataset_uri }  
      dataset.add_metadata(metadata)
      test_dataset.compounds.each{|c| dataset.add_compound(c)}
      predicted_feature = File.join( uri, "predicted", "value")
      dataset.add_feature(predicted_feature)
      count = 0
      test_dataset.compounds.each do |c|
        num_compounds[c].times do
          dataset.add(c,predicted_feature,predictions[count],true)
          count += 1
        end
      end
      raise unless count==predictions.size
      dataset.save(subjectid)
      
      predicted = self.predicted_datasets
      predicted[dataset_uri] = dataset.uri
      self.predicted_datasets = predicted
      self.save
      test_dataset.delete if created_modified_test_dataset
      File.delete(data_file.path)
      dataset.uri
    end
    
    def uri
      raise "no id" if self.id==nil
      $url_provider.url_for("/"+self.weka_algorithm.split(".")[-1]+"/"+self.id.to_s, :full)
    end
    
    def delete_model
      uri = self.uri
      LOGGER.debug "deleting #{uri}"
      [ model_file(), training_arff_file(), test_arff_file() ].each do |f|
        begin
          LOGGER.debug "deleting file #{f}"
          File.delete(f)
        rescue => ex
          LOGGER.warn "could not delete file #{ex.message}"
        end
      end
      LOGGER.debug "deleting from database"
      self.delete
      "model #{uri} deleted\n"
    end
    
  end
  
end
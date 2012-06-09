module OpenTox
  
  module DatasetUtil

    def self.dataset_to_arff( dataset, missing_value="NA", subjectid=nil, features=nil )
      
      LOGGER.debug "convert dataset to arff #{dataset.uri}"
            
      # count duplicates
      num_compounds = {}
      dataset.features.keys.each do |f|
        dataset.compounds.each do |c|
          if dataset.data_entries[c]
            val = dataset.data_entries[c][f]
            size = val==nil ? 1 : val.size
            num_compounds[c] = num_compounds[c]==nil ? size : [num_compounds[c],size].max
          else
            num_compounds[c] = 1
          end
        end
      end  
      
      # use either all, or the provided features, sorting is important as col-index := features
      if features
        features.sort!
      else
        features = dataset.features.keys.sort
      end
      compounds = []
      compound_names = []
      dataset.compounds.each do |c|
        count = 0
        num_compounds[c].times do |i|
          compounds << c
          compound_names << "#{c}$#{count}"
          count+=1
        end
      end
      
      arff = "@RELATION #{dataset.uri}\n\n"
      features.each do |f|
        feat = OpenTox::Feature.find(f,subjectid)
        nominal = feat.metadata[RDF.type].to_a.flatten.include?(OT.NominalFeature)
        if nominal
          arff << "@ATTRIBUTE #{f} {#{dataset.accept_values(f).join(",")}}\n"
        else
          arff << "@ATTRIBUTE #{f} NUMERIC\n"
        end
      end

      arff << "\n@DATA\n"
      
      dataset.compounds.each do |c|
        num_compounds[c].times do |i|
          c_values = []
          features.each do |f|
            if dataset.data_entries[c]
              val = dataset.data_entries[c][f]
              v = val==nil ? "" : val[i].to_s
            else
              raise "wtf" if i>0
              v = ""
            end
            v = missing_value if v.size()==0
            c_values << v
          end
          arff << "#{c_values.join(",")}\n"
        end
      end
      arff
    end
    
  end
  
  
end
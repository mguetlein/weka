
unless ENV["JAVA_HOME"]
  ["/usr/lib/jvm/java-6-sun-1.6.0.24","/usr/lib/jvm/java-6-openjdk"].each do |jh|
    if File.directory?(jh)
      ENV["JAVA_HOME"] = jh
      break
    end
  end
  raise "no java home found" unless ENV["JAVA_HOME"]
end      
  
class String
  def is_numeric?
    Float(self)
    true 
  rescue 
    false
  end
end

class Array
  def numeric_strings?
    self.each{ |x| return false unless x.is_a?(String) and  x.is_numeric? }
  end
end  


module WekaCommandLine

  def self.init
    Rjb::load("weka.jar", jvmargs=["-Xmx1000M","-Djava.awt.headless=true"])
  end
  
  def self.java_version
    stdout_str, stderr_str = ProcessUtil.run("java -version")
    stderr_str
  end
  
  def self.build_model(algorithm, data_file, class_feature_index, model_file)
    cmd = "java -cp weka.jar #{algorithm} -t #{data_file} -c #{class_feature_index} -d #{model_file}"
    LOGGER.debug "building model '#{cmd}'"
    stdout_str, stderr_str = ProcessUtil.run(cmd)
  end
  
  def self.feature_weights(model_file)
    cmd = "java -jar weka_weights.jar #{model_file}"
    LOGGER.debug "compute weka weights '#{cmd}'"
    stdout_str, stderr_str = ProcessUtil.run(cmd)
    LOGGER.debug stderr_str.gsub(/\n/,"; ")
    stdout_str
  end  
  
  def self.apply_model(algorithm, data_file, class_feature_index, model_file, feature_type)
    cmd = "java -cp weka.jar #{algorithm} -T #{data_file} -c #{class_feature_index} -l #{model_file} -p 0"
    LOGGER.debug "apply model '#{cmd}'"
    predictions = []
    stdout_str, stderr_str = ProcessUtil.run(cmd)
    index = 1
    stdout_str.split("\n").each do |line|
      if feature_type=="classification"
        match = line.match(/\s([0-9]+)\s*[0-9]+:.*\s*[0-9]+:([^\s]*)\s/)
        if (match)
          raise "#{match.captures[0]} != #{index}" if match.captures[0].to_i!=index
          index += 1
          predictions << match.captures[1]    
        end
      elsif feature_type=="regression"   
        vals = line.split
        if vals.size==4 and (vals.numeric_strings? || 
          (vals[0].is_numeric? && vals[1]=='?' && vals[2].is_numeric? && vals[3]=='?') )
          raise if vals[0].to_i!=index
          index += 1
          predictions << vals[2]
        end
      else
        raise "invalid feature_type: #{feature_type}"
      end
    end
    LOGGER.debug "predictions: #{predictions.size} : [ #{predictions.join(" ")[0..255]} ... ]"
    predictions
  end
  
#  def self.predict_data(model, data)
#    data.numInstances.times do |instance|
#      pred = model.classifyInstance(data.instance(instance))
#      puts pred
#    end
#  end

end

require 'rjb'

#def kmeans
#  #examine the particular datapoints
#  points = labor_data.numInstances
#  points.times do |instance|
#    cluster = kmeans.clusterInstance(labor_data.instance(instance))
#    point = labor_data.instance(instance).toString
#    puts "#{point} \t #{cluster}"
#  end
#end

module WekaRjb

  def self.init
    ENV["JAVA_HOME"] = "/usr/lib/jvm/java-6-openjdk" unless ENV["JAVA_HOME"]
    Rjb::load("weka.jar", jvmargs=["-Xmx1000M","-Djava.awt.headless=true"])
  end
  
  def self.load_data_str(arff_string)
      src = Rjb::import("java.io.StringReader").new(arff_string)
      data = Rjb::import("weka.core.Instances").new(src)
      data.setClassIndex( data.numAttributes - 1 )
      data
  end
  
  def self.load_data(arff_file)
    src = Rjb::import("java.io.FileReader").new(arff_file)
    data = Rjb::import("weka.core.Instances").new(src)
    data.setClassIndex( data.numAttributes - 1 )
    data
  end
  
  def self.build_model(m, data)
    LOGGER.debug "build model"
    model = Rjb::import(m).new
    model.buildClassifier(data)
    model
  end
  
  def self.serialize(model, file)
    LOGGER.debug "serialize model"
    sh = Rjb::import("weka.core.SerializationHelper")
    sh.write(file, model);
  end
  
  def self.deserialize(file)
    LOGGER.debug "deserialize model"
    sh = Rjb::import("weka.core.SerializationHelper")
    model = sh.read(file);
  end
  
  def self.predict_data(model, data)
    data.numInstances.times do |instance|
      pred = model.classifyInstance(data.instance(instance))
      LOGGER.debug pred
    end
  end

end
  
WekaRjb::init
#arff = "/home/martin/workspace/external/weka-3-7-2/data/iris.arff"
#alg = "weka.classifiers.trees.RandomForest"
#alg = "weka.classifiers.bayes.NaiveBayes"

#data = load_data(arff)

#model = build_model(alg, data)
#serialize(model,"/tmp/weka.model")

#model = deserialize("/tmp/weka.model")

#predict_data(model, data)

#puts model.toString
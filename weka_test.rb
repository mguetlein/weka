
require "rubygems"
require "sinatra"
before {
  request.env['HTTP_HOST']="local-ot/weka"
  request.env["REQUEST_URI"]=request.env["PATH_INFO"]
}

require "uri"
require "yaml"
ENV['RACK_ENV'] = 'production'
require 'application.rb'
require 'test/unit'
require 'rack/test'

LOGGER = OTLogger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
LOGGER.formatter = Logger::Formatter.new

if AA_SERVER
  #TEST_USER = "mgtest"
  #TEST_PW = "mgpasswd"
  TEST_USER = "guest"
  TEST_PW = "guest"
  SUBJECTID = OpenTox::Authorization.authenticate(TEST_USER,TEST_PW)
  raise "could not log in" unless SUBJECTID
  puts "logged in: "+SUBJECTID.to_s
else
  puts "AA disabled"
  SUBJECTID = nil
end

#Rack::Test::DEFAULT_HOST = "local-ot" #"/validation"
module Sinatra
  
  set :raise_errors, false
  set :show_exceptions, false

  module UrlForHelper
    BASE = "http://local-ot/weka"
    def url_for url_fragment, mode=:path_only
      case mode
      when :path_only
        raise "not impl"
      when :full
      end
      "#{BASE}#{url_fragment}"
    end
  end
end


module Lib
  # test utitily, to be included rack unit tests
  module TestUtil
    
    def wait_for_task(uri)
      return TestUtil.wait_for_task(uri)
    end
    
    def self.wait_for_task(uri)
      if uri.task_uri?
        task = OpenTox::Task.find(uri)
        task.wait_for_completion
        #raise "task failed: "+uri.to_s+", error is:\n"+task.description if task.error?
        LOGGER.error "task failed :\n"+task.to_yaml if task.error?
        uri = task.result_uri
      end
      return uri
    end
  end
end


class WekaTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil
  
  def test_it
    begin
      
     # dataset = OpenTox::Dataset.create_from_csv_file(File.new("data/kazius.250.active.cdkdesc.csv").path, nil)
     # puts dataset.uri
     # exit
      
   #   dataset_uri = "http://local-ot/dataset/503" #kazius.250.active.cdkdesc.csv
   #   prediction_feature = "http://local-ot/dataset/503/feature/endpoint"
  #    training_dataset_uri = "http://local-ot/dataset/504"
    #  test_dataset_uri = "http://local-ot/dataset/505"
      
#      dataset_uri = "http://local-ot/dataset/477" #hamstser ob features
#      prediction_feature = "http://local-ot/dataset/477/feature/Hamster%20Carcinogenicity"
#      training_dataset_uri = "http://local-ot/dataset/484"
#      test_dataset_uri = "http://local-ot/dataset/485"
      
      #dataset_uri = "http://local-ot/dataset/753"
      #training_dataset_uri = "http://local-ot/dataset/754"
      #test_dataset_uri = "http://local-ot/dataset/755"
      #prediction_feature = "http://local-ot/dataset/753/feature/Hamster%20Carcinogenicity"
      #alg = "J48"
      
      dataset_uri = "http://local-ot/dataset/8998"
      training_dataset_uri = "http://local-ot/dataset/9006"
      test_dataset_uri = "http://local-ot/dataset/9007"
      prediction_feature = "http://local-ot/dataset/8998/feature/Hamster%20Carcinogenicity"
      alg = "J48"
      
      #prediction_feature = "http://local-ot/dataset/7501/feature/LOGINV_MRDD_mmol"
      #training_dataset_uri= "http://local-ot/dataset/7502"
      #test_dataset_uri="http://local-ot/dataset/7503"
      #alg = "M5P"
      
      #dataset_uri = "http://opentox.informatik.uni-freiburg.de/dataset/3075" #hamster 
      #prediction_feature = "http://opentox.informatik.uni-freiburg.de/dataset/3075/feature/Hamster%20Carcinogenicity"
      
      #dataset_uri = "http://opentox.informatik.uni-freiburg.de/dataset/1962" #kazius cdk 250
      #prediction_feature = "http://apps.ideaconsult.net:8080/ambit2/feature/5643728"
      
     params = {:dataset_uri => training_dataset_uri, :prediction_feature => prediction_feature }
      
     post "/#{alg}",params
     uri = last_response.body
     model = wait_for_task(uri)
     puts "model #{model}"
     
     id = model.split("/").last
     
#     id = "2891"
#     test_dataset_uri = "http://local-ot/dataset/8331"
     
     params = {:dataset_uri => test_dataset_uri}
     post "/#{alg}/#{id}",params
     uri = last_response.body
     model = wait_for_task(uri)
     puts "prediction dataset #{model}"           
    # 
     
#      host = "http://local-ot/"
##      host = "http://opentox.informatik.uni-freiburg.de/"
#      superservice="#{host}weka"
#      params = {
#        :dataset_uri=>dataset_uri,
#        #:training_dataset_uri=>dataset_uri, :test_dataset_uri=>dataset_uri,
#        :prediction_feature => prediction_feature, :algorithm_uri=>"#{host}weka/J48" }
#      #validation = "#{host}validation/training_test_validation"
#      validation = "#{host}validation/training_test_split"
#      puts OpenTox::RestClientWrapper.post(validation, params)  
      
    rescue => ex
      rep = OpenTox::ErrorReport.create(ex, "")
      puts rep.to_yaml
    ensure
      #OpenTox::Authorization.logout(SUBJECTID) if AA_SERVER
    end
  end

  def app
    Sinatra::Application
  end
end


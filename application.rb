require 'rubygems'
require 'opentox-ruby'

require 'weka.rb'

get '/java_version' do
  Weka.java_version+"\n"
end

post '/:weka_algorithm/:id' do
  model = Weka::WekaModel.get(params[:id])
  raise OpenTox::NotFoundError.new("weka-model '#{params[:id]}' not found.") unless model
  [:dataset_uri].each do |p|
    raise OpenTox::BadRequestError.new("#{p} missing") unless params[p].to_s.size>0
  end
  LOGGER.info "applying weka model #{model.uri} with params #{params.inspect}"

  dataset = model.find_predicted_model(params[:dataset_uri])
  if dataset
    LOGGER.info "found already existing weka prediction dataset: #{dataset}"
    dataset
  else
    task = OpenTox::Task.create( "Apply Model #{model.uri}", url_for("/", :full) ) do |task|
      res = model.apply(params[:dataset_uri], task)
      LOGGER.info "weka model prediction done: #{res}"
      res
    end
    return_task(task)
  end
end

post '/:weka_algorithm' do
  [:dataset_uri, :prediction_feature].each do |p|
    raise OpenTox::BadRequestError.new("#{p} missing") unless params[p].to_s.size>0
  end
  LOGGER.info "creating weka model with params #{params.inspect}"
  
  model = Weka::WekaModel.find_model(params)
  if model
    LOGGER.info "found already existing model: #{model}"
    model
  else
    task = OpenTox::Task.create( "Create Model", url_for("/", :full) ) do |task|
      model = Weka::WekaModel.create(params,@subjectid)
      model.build(task)
      LOGGER.info "weka model created: #{model.uri}"
      model.uri
    end
    return_task(task)
  end  
end

get '/?' do
  uri_list = Weka::WekaModel.all.sort.collect{|v| v.uri}.join("\n") + "\n"
  LOGGER.debug "list weka models"
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    content_type "text/html"
    OpenTox.text_to_html uri_list,@subjectid
  else
    content_type "text/uri-list"
    uri_list
  end
end

get '/:weka_algorithm/:id' do
  model = Weka::WekaModel.get(params[:id])
  raise OpenTox::NotFoundError.new("weka-model '#{params[:id]}' not found.") unless model
  LOGGER.debug "get weka model #{model.uri} #{params}"
  case request.env['HTTP_ACCEPT']
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    model.to_rdf
  when /html/
    model.inspect
    OpenTox.text_to_html model.to_yaml
  else
    raise "not yet implemented #{request.env['HTTP_ACCEPT']}"
  end  
end

delete '/:weka_algorithm/:id' do
  model = Weka::WekaModel.get(params[:id])
  raise OpenTox::NotFoundError.new("weka-model '#{params[:id]}' not found.") unless model
  LOGGER.info "deleting weka model #{model.uri}"
  content_type "text/plain"
  model.delete_model
end

get '/:weka_algorithm/:id/weights' do
  model = Weka::WekaModel.get(params[:id])
  raise OpenTox::NotFoundError.new("weka-model '#{params[:id]}' not found.") unless model
  case @accept
  when /html/
    content_type "text/html"
    OpenTox.text_to_html model.feature_weights_dynamic
  else
    content_type "text/plain"
    model.feature_weights_dynamic
  end
end

get '/:weka_algorithm/:id/predicted/:prop' do
  model = Weka::WekaModel.get(params[:id])
  raise OpenTox::NotFoundError.new("weka-model '#{params[:id]}' not found.") unless model
  model.subjectid = @subjectid
  if params[:prop] == "value"
    feature = model.prediction_value_feature
  elsif params[:prop] == "confidence"
    feature = model.prediction_confidence_feature
  else
    raise OpenTox::BadRequestError.new "Unknown URI #{@uri}"
  end
  case @accept
  when /yaml/
    content_type "application/x-yaml"
    feature.metadata.to_yaml
  when /rdf/
    content_type "application/rdf+xml"
    feature.to_rdfxml
  when /html/
    content_type "text/html"
    OpenTox.text_to_html feature.metadata.to_yaml
  else
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
  end
end




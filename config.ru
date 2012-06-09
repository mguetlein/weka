require 'rubygems'
require 'sinatra'
require 'application.rb'
require 'config/config_ru'
run Sinatra::Application
set :raise_errors, false
set :show_exceptions, false
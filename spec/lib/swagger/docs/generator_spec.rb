require 'spec_helper'
require 'apps'
require 'fixtures/controllers/application_controller'
require 'fixtures/controllers/ignored_controller'

describe Swagger::Docs::Generator do
  before(:each) do
    FileUtils.rm_rf(tmp_dir)
    stub_const('ActionController::Base', ApplicationController)
    allow(Rails).to receive(:application).and_return(Main::Application)
  end

  let(:tmp_dir) { Pathname.new('/tmp/swagger-docs/') }
  let(:file_resources) { tmp_dir + 'api-docs.json' }
  let(:file_resource) { tmp_dir + 'api/v1/sample.json' }
  let(:file_resource_nested) { tmp_dir + 'nested.json' }
  let(:file_resource_custom_resource_path) { tmp_dir + 'custom_resource_path.json' }

  let(:default_config) {
    {
      :controller_base_path => "api/v1",
      :api_file_path => "#{tmp_dir}",
      :base_path => "http://api.no.where/",
      :attributes => {
        :info => {
          "title" => "Swagger Sample App",
          "description" => "This is a sample description.",
          "termsOfServiceUrl" => "http://helloreverb.com/terms/",
          "contact" => "apiteam@wordnik.com",
          "license" => "Apache 2.0",
          "licenseUrl" => "http://www.apache.org/licenses/LICENSE-2.0.html"
        }
      }
    }
  }

  let(:controllers) { [
    "fixtures/controllers/sample_controller",
    "fixtures/controllers/nested_controller",
    "fixtures/controllers/custom_resource_path_controller",
    "fixtures/controllers/multiple_routes_controller"
  ]}

  shared_context :resource_apis do
    let(:resource) { file_resource.read }
    let(:response) { JSON.parse(resource) }
    let(:apis) { response["apis"] }
  end

  context "without controller base path" do
    let(:default_config) { {:api_file_path => "#{tmp_dir}", :base_path => "http://api.no.where/"} }
    let(:config) { {DEFAULT_VER => default_config} }
    before(:each) do
      Swagger::Docs::Generator.set_real_methods
      controllers.each{ |path| require path }
      generate(config)
    end
    context "resources files" do
      let(:resources) { file_resources.read }
      let(:response) { JSON.parse(resources) }
      it "writes basePath correctly" do
        expect(response["basePath"]).to eq "http://api.no.where"
      end
      it "writes apis correctly" do
        expect(response["apis"].count).to eq controllers.count
      end
      it "writes api path correctly" do
        expect(response["apis"][0]["path"]).to eq "/api/v1/sample.{format}"
      end

      context "api_file_name" do
        let(:api_file_name) { 'swagger-docs.json' }
        let(:config) {{
          DEFAULT_VER => {
            :api_file_path => tmp_dir,
            :api_file_name => api_file_name }
        }}
        let(:file_resources) { tmp_dir + api_file_name }
        specify { expect(File.exists? file_resources).to be true }
      end
    end
    context "resource file" do
      let(:resource) { file_resource.read }
      let(:response) { JSON.parse(resource) }
      let(:first) { response["apis"].first }
      let(:operations) { first["operations"] }
      # {"apiVersion":"1.0","swaggerVersion":"1.2","basePath":"/api/v1","resourcePath":"/sample"
      it "writes basePath correctly" do
        expect(response["basePath"]).to eq "http://api.no.where"
      end
      it "writes resourcePath correctly" do
        expect(response["resourcePath"]).to eq "sample"
      end
      it "writes out expected api count" do
        expect(response["apis"].count).to eq 7
      end
      context "first api" do
        #"apis":[{"path":" /sample","operations":[{"summary":"Fetches all User items"
        #,"method":"get","nickname":"Api::V1::Sample#index"}]
        it "writes path correctly" do
          expect(first["path"]).to eq "/api/v1/sample"
        end
      end
    end

    context 'blog engine' do
      include_context :resource_apis
      let(:controllers) { super() | ["fixtures/controllers/blog/articles_controller"] }
      let(:file_resource) { tmp_dir + "blog/articles.json" }

      context 'when main_application is NOT set' do
        let(:default_config) { super().merge(:applications => [Main::Application, Blog::Engine]) }
        it do
          expect(apis).to contain_exactly(
            "path" => "/blog/articles",
            "operations" => contain_exactly(
              a_hash_including(
                "summary" => "Fetches all Blog Articles",
                "nickname" => "Blog::Articles#index",
                "method" => "get"
              )
            )
          )
        end
      end

      context 'when main_application is set' do
        let(:default_config) { super().merge(:main_application => Main::Application, :applications => [Blog::Engine]) }
        it do
          expect(apis).to contain_exactly(
            "path" => "/blog/articles",
            "operations" => contain_exactly(
              a_hash_including(
                "summary" => "Fetches all Blog Articles",
                "nickname" => "Blog::Articles#index",
                "method" => "get"
              )
            )
          )
        end
      end
    end
  end
  context "with controller base path" do
    let(:config) { Swagger::Docs::Config.register_apis({DEFAULT_VER => default_config})}
    let(:file_resource) { tmp_dir + 'sample.json' }
    let(:resource) { file_resource.read }
    let(:response) { JSON.parse(resource) }
    let(:apis) { response["apis"] }
    before(:each) do
      Swagger::Docs::Generator.set_real_methods
      controllers.each{ |path| require path }
    end
    context "test suite initialization" do
      it "the resources file does not exist" do
        expect(file_resource).to_not exist
      end
      it "the resource file does not exist" do
        expect(file_resource).to_not exist
      end
    end
    describe "#generate" do
      context "with configuration option :parent_controller" do
        let(:config) { default_config.merge!(:parent_controller => parent_controller) }
        let(:api_config) { Swagger::Docs::Config.register_apis(DEFAULT_VER => config) }
        let(:results) { generate(api_config) }

        context 'when class' do
          let(:parent_controller) { Api::V1::SuperclassController }
          it { expect(results[DEFAULT_VER][:processed].count).to eq(2) }
        end

        context 'when class name' do
          let(:parent_controller) { 'Api::V1::SuperclassController' }
          it { expect(results[DEFAULT_VER][:processed].count).to eq(2) }
        end

        context 'when array of class names' do
          let(:parent_controller) { ['Api::V1::SuperclassController', 'Api::V1::NestedSuperclassController'] }
          it { expect(results[DEFAULT_VER][:processed].count).to eq(3) }
        end
      end
    end
    describe "#write_docs" do
      context "no apis registered" do
        before(:each) do
          Swagger::Docs::Config.register_apis({})
        end
        it "generates using default config" do
          results = generate({})
          expect(results[DEFAULT_VER][:processed].count).to eq(controllers.count)
        end
      end
      before(:each) do
        generate(config)
      end
      context "api-docs resources file" do
        it "writes the file" do
         expect(file_resources).to exist
        end
        context "custom user attributes" do
          let(:parsed_resources) {
            JSON.parse(File.read file_resources)
          }
          it "it has info hash" do
            expect(parsed_resources.keys).to include("info")
          end
          it "has title field" do
            expect(parsed_resources["info"]["title"]).to eq "Swagger Sample App"
          end
          it "has description field" do
            expect(parsed_resources["info"]["description"]).to eq "This is a sample description."
          end
        end
      end
      it "cleans json files in directory when set" do
        file_to_delete = Pathname.new(File.join(config['1.0'][:api_file_path], 'delete_me.json'))
        File.open(file_to_delete, 'w') {|f| f.write("{}") }
        expect(file_to_delete).to exist
        config[DEFAULT_VER][:clean_directory] = true
        generate(config)
        expect(file_to_delete).to_not exist
      end
      it "keeps non json files in directory when cleaning" do
        file_to_keep = Pathname.new(File.join(config['1.0'][:api_file_path], 'keep_me'))
        File.open(file_to_keep, 'w') {|f| f.write("{}") }
        config[DEFAULT_VER][:clean_directory] = true
        generate(config)
        expect(file_to_keep).to exist
      end
      it "writes the resource file" do
         expect(file_resource).to exist
      end
      it "returns results hash" do
        results = generate(config)
        expect(results[DEFAULT_VER][:processed].count).to eq(controllers.count)
        expect(results[DEFAULT_VER][:skipped].count).to eq 1
      end
      it "writes pretty json files when set" do
        config[DEFAULT_VER][:formatting] = :pretty
        generate(config)
        resources = File.read file_resources
        expect(resources.scan(/\n/).length).to be > 1
      end
      context "resources files" do
        let(:resources) { file_resources.read }
        let(:response) { JSON.parse(resources) }
        it "writes version correctly" do
          expect(response["apiVersion"]).to eq DEFAULT_VER
        end
        it "writes swaggerVersion correctly" do
          expect(response["swaggerVersion"]).to eq "1.2"
        end
        it "writes basePath correctly" do
          expect(response["basePath"]).to eq "http://api.no.where/api/v1"
        end
        it "writes apis correctly" do
          expect(response["apis"].count).to eq(controllers.count)
        end
        it "writes api path correctly" do
          expect(response["apis"][0]["path"]).to eq "/sample.{format}"
        end
        it "writes api description correctly" do
          expect(response["apis"][0]["description"]).to eq "User Management"
        end
      end
      context "nested resource file" do
        let(:resource) { file_resource_nested.read }
        let(:response) { JSON.parse(resource) }
        let(:apis) { response["apis"] }
        context "apis" do
          context "show" do
            let(:api) { get_api_operation(apis, "/nested/{nested_id}/nested_sample", :get) }
            let(:operations) { get_api_operations(apis, "/nested/{nested_id}/nested_sample") }
            context "parameters" do
              it "has correct count" do
                expect(api["parameters"].count).to eq 2
              end
            end
          end
        end
      end
      context "multiple routes resource file" do
        let(:file_resource) { tmp_dir + 'multiple_routes.json' }
        it "handles multiple GET path" do
          resource = get_api_operation(apis, "/multiple_routes", :get)
          expect(resource["method"]).to eq "get"
        end
        it "handles multiple POST path" do
          resource = get_api_operation(apis, "/multiple_routes", :post)
          expect(resource["method"]).to eq "post"
        end
      end
      context "sample resource file" do
        # {"apiVersion":"1.0","swaggerVersion":"1.2","basePath":"/api/v1","resourcePath":"/sample"
        it "writes version correctly" do
          expect(response["apiVersion"]).to eq DEFAULT_VER
        end
        it "writes swaggerVersion correctly" do
          expect(response["swaggerVersion"]).to eq "1.2"
        end
        it "writes basePath correctly" do
          expect(response["basePath"]).to eq "http://api.no.where/api/v1"
        end
        it "writes resourcePath correctly" do
          expect(response["resourcePath"]).to eq "sample"
        end
        it "writes out expected api count" do
          expect(response["apis"].count).to eq 7
        end
        describe "context dependent documentation" do
          after(:each) do
            ApplicationController.context = "original"
          end
          let(:operations) { get_api_operations(apis, "/context_dependent") }
          it "should be the original" do
            ApplicationController.context = "original"
            generate(config)
            expect(operations.first["summary"]).to eq "An action dependent on the context of the controller class. Right now it is: original"
          end
          context "when modified" do
            it "should be modified" do
              ApplicationController.context = "modified"
              generate(config)
              expect(operations.first["summary"]).to eq "An action dependent on the context of the controller class. Right now it is: modified"
            end
          end
        end
        context "apis" do
          context "index" do
            let(:api) { get_api_operation(apis, "/sample", :get) }
            let(:operations) { get_api_operations(apis, "/sample") }
            #"apis":[{"path":" /sample","operations":[{"summary":"Fetches all User items"
            #,"method":"get","nickname":"Api::V1::Sample#index"}]
            it "writes path correctly when api extension type is not set" do
              expect(apis.first["path"]).to eq "/sample"
            end
            it "writes path correctly when api extension type is set" do
              config[DEFAULT_VER][:api_extension_type] = :json
              generate(config)
              expect(apis.first["path"]).to eq "/sample.json"
            end
            it "writes summary correctly" do
              expect(operations.first["summary"]).to eq "Fetches all User items"
            end
            it "writes method correctly" do
              expect(operations.first["method"]).to eq "get"
            end
            it "writes nickname correctly" do
              expect(operations.first["nickname"]).to eq "Api::V1::Sample#index"
            end
            it "writes responseModel attribute" do
              expect(api["responseMessages"].find{|m| m["responseModel"] == "Tag"}).to_not be_nil
            end
            it "writes response code as 200" do
              expect(api["responseMessages"].find{|m| m["responseModel"] == "Tag"}["code"]).to eq 200
            end
            #"parameters"=>[
            # {"paramType"=>"query", "name"=>"page", "type"=>"integer", "description"=>"Page number", "required"=>false},
            # {"paramType"=>"path", "name"=>"nested_id", "type"=>"integer", "description"=>"Team Id", "required"=>false}], "responseMessages"=>[{"code"=>401, "message"=>"Unauthorized"}, {"code"=>406, "message"=>"The request you made is not acceptable"}, {"code"=>416, "message"=>"Requested Range Not Satisfiable"}], "method"=>"get", "nickname"=>"Api::V1::Sample#index"}
            #]
            context "parameters" do
              let(:params) { operations.first["parameters"] }
              it "has correct count" do
                expect(params.count).to eq 1
              end
              it "writes paramType correctly" do
                expect(params.first["paramType"]).to eq "query"
              end
              it "writes name correctly" do
                expect(params.first["name"]).to eq "page"
              end
              it "writes type correctly" do
                expect(params.first["type"]).to eq "integer"
              end
              it "writes description correctly" do
                expect(params.first["description"]).to eq "Page number"
              end
              it "writes required correctly" do
                expect(params.first["required"]).to be_falsey
              end
            end
            context "list parameter" do
              let(:api) { get_api_operation(apis, "/sample", :patch) }
              let(:params) {api["parameters"] }
              it "writes description correctly" do
                expect(params[3]["description"]).to eq "Role"
              end
            end
            #"responseMessages":[{"code":401,"message":"Unauthorized"},{"code":406,"message":"Not Acceptable"},{"code":416,"message":"Requested Range Not Satisfiable"}]
            context "response messages" do
              let(:response_msgs) { operations.first["responseMessages"] }
              it "has correct count" do
                expect(response_msgs.count).to eq 4
              end
              it "writes code correctly" do
                expect(response_msgs.first["code"]).to eq 200
              end
              it "writes message correctly" do
                expect(response_msgs.first["message"]).to eq "Some text"
              end
              it "writes specified message correctly" do
                expect(response_msgs[1]["message"]).to eq "Unauthorized"
              end
            end
          end
          context "create" do
            let(:api) { get_api_operation(apis, "/sample", :patch) }
            it "writes list parameter values correctly" do
              expected_param = {"valueType"=>"LIST", "values"=>["admin", "superadmin", "user"]}
              expected_body = {"paramType"=>"body", "name"=>"body", "type"=>"json", "description"=>"JSON formatted body", "required"=>true}
              expected_consumes = ["application/json", "text/xml"]
              expect(get_api_parameter(api, "role")["allowableValues"]).to eq expected_param
              expect(get_api_parameter(api, "body")).to eq expected_body
              expect(api["consumes"]).to eq ["application/json", "text/xml"]
              expect(api["items"]).to eq("{$ref\" => \"setup\"}")
            end
            it "doesn't write out route put method" do
              expect(get_api_operation(apis, "sample", :put)).to be_nil
            end
          end
          context "update" do
            let(:api) { get_api_operation(apis, "/sample/{id}", :put) }
            it "writes notes correctly" do
              expect(api["notes"]).to eq "Only the given fields are updated."
            end
            it "writes model param correctly" do
              expected_param = {
                "paramType" => "form",
                "name" => "tag",
                "type" => "Tag",
                "description" => "Tag object",
                "required" => true,
              }
              expect(get_api_parameter(api, "tag")).to eq expected_param
            end
          end
        end
        context "models" do
          let(:models) { response["models"] }
          # Based on https://github.com/wordnik/swagger-core/wiki/Datatypes
          it "writes model correctly" do
            expected_model = {
              "id" => "Tag",
              "required" => ["id"],
              "description" => "A Tag object.",
              "properties" => {
                "name" => {
                  "type" => "string",
                  "description" => "Name",
                  "foo" => "test",
                },
                "id" => {
                  "type" => "integer",
                  "description" => "User Id",
                },
                "type" => {
                  "type" => "string",
                  "description" => "Type",
                  "allowableValues" => {
                    "valueType" => "LIST",
                    "values" => [
                      "info",
                      "warning",
                      "error"
                    ]
                  }
                }
              }
            }
            expect(models['Tag']).to eq expected_model
          end
        end
        context "custom resource_path resource file" do
          let(:resource) { file_resource_custom_resource_path.read }
          let(:response) { JSON.parse(resource) }
          let(:apis) { response["apis"] }
          # {"apiVersion":"1.0","swaggerVersion":"1.2","basePath":"/api/v1","resourcePath":"/sample"
          it "writes resourcePath correctly" do
            expect(response["resourcePath"]).to eq "resource/testing"
          end
        end
      end
    end
  end
end

module Workhorse
  class SendImageRequest
   #require 'net/sftp'
    MAX_IDS_PER_CRUD = 100.freeze
    PROPERTY_NRF_COLOR_CODE = 'nrfColorCode'.freeze
    PROPERTY_COLOR_MASTER = 'Color Master?'.freeze
    SELECTIONS = [
      'Vendor#',
      'vendorNumber',
      'Dept#',
      'Class#',
      'Turn-In Date',
      'ImageAssetSource'
    ].freeze
    @photoRequests
    @fileName
    def self.run
      new.run
    end

    def run

      binding.pry
      photo_requests_to_send
      # TODO: Iterate over products_to_send and generate xml
      binding.pry
      to_xml(@photoRequests)
      # TODO: Send xml to workhorse
      transferFile
      binding.pry
      # TODO: Mark sample requests as sent to workhorse
    end


    def photo_requests_to_send
      smapleRequests = []
      getUnsentSampleRequest
      filter="="
              @photo_requests.each  do |sample_request|
                # TODO need to limit the number of products else request may get fail
                 #next unless color_master
              filter+="'Parent Product':'"
              filter+= sample_request["product_id"]
              filter+="','nrfColorCode':'"
              filter+=sample_request["color_id"].strip
              filter+="','Color Master?':'true'="
              end
              binding.pry
          filter.slice!(0,filter.length-1)
      #    puts(filter)
           binding.pry
          @photoRequests = retrieve_color_master(filter)
      #    puts(@photoRequests)

    end
    # def formatFilterRequest
    #
    # end
    def transferFile
      require 'net/sftp'
      Net::SFTP.start('belkuat.workhorsegroup.us', 'BLKUATUSER', :password => '5ada833014a4c092012ed3f8f82aa0c1') do |sftp|
       # upload a file or directory to the remote host
       binding.pry
      sftp.upload!(@fileName, File.join('SalsifyImportToWH',File.basename(@fileName)))


    end
    end

    def to_xml(photoRequests)
    ##  puts(attributes.dept)
      @fileName = '/Users/afusrg1/Subba/Ruby/belkApp/photoRequest/photoRequests_'+Time.now.strftime('%Y-%m-%d_%H-%M-%S')+'.xml'
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.root {
          xml.Project {
            photoRequests.each do |photo_request|
            color_master=ColorMaster.new(photo_request)
            xml.ShotGroup('id' => color_master.product_id, 'CollectionOrGroup' => 'N', 'SalsifyID' => '12345') {
              xml.Image('id' => color_master.product_id){
               xml.Sample('deptnnum' => '123'){
                  xml.id_ "10"
                }
              }
            }
          end
          }
        }
      end
      binding.pry
      File.write(@fileName, builder.to_xml)
      puts builder.to_xml
    end

    def retrieve_color_master(filter)
      salsify.products_filtered_by(
        filter: filter,
        selections: SELECTIONS
      ).products
    end

    def unsent_sample_requests
      @unsent_sample_requests ||= [
        SampleRequest.where(sent_to_workhorse: false),
        SampleRequest.where(sent_to_workhorse: nil)
      ].flatten
    end

    def salsify
      @salsify ||= Salsify::Client.create_with_token(
        ENV.fetch('SALSIFY_USER_EMAIL'),
        ENV.fetch('SALSIFY_API_TOKEN'),
        organization_id: ENV.fetch('SALSIFY_ORG_SYSTEM_ID')
      )
    end

    def getUnsentSampleRequest
      response = RestClient::Request.new({
        method: :get,
        url: 'https://customer-belk-qa.herokuapp.com/api/workhorse/sample_requests?unsent=true',
        headers: { :api_token => '4591D7EF39D6CFE0482778AACB8A0534B99DB31317D528E310373B1BC0E16E22' }
      }).execute do |response, request, result|
        case response.code
        when 400
            @photo_requests=JSON.parse(response.body)
        when 200
          @photo_requests=JSON.parse(response.body)
        #  puts(@unsent_sample_requests)
        #  [ :success, parse_json(response.to_str) ]
        else
          fail "Invalid response #{response.to_str} received."
        end
      end
    end

  end
end

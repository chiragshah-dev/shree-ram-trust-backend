# class FcmService
#   def self.send_notification(fcm_token:, title:, body:, data: {})
#     return if fcm_token.blank?

#     client = FCM.new(Rails.application.credentials.dig(:fcm, :server_key))

#     response = client.send_v1(
#       {
#         token: fcm_token,
#         notification: {
#           title: title,
#           body:  body
#         },
#         data: data.transform_values(&:to_s)
#       }
#     )

#     Rails.logger.info("FCM Response: #{response.inspect}")
#     response
#   rescue => e
#     Rails.logger.error("FCM Error: #{e.message}")
#     nil
#   end
# end

# app/services/fcm_service.rb
require 'googleauth'
require 'faraday'
require 'json'

class FcmService
  FIREBASE_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

  def self.send_notification(fcm_token:, title:, body:, data: {})
    return if fcm_token.blank?
    access_token = fetch_access_token

    conn = Faraday.new(
      url: "https://fcm.googleapis.com/v1/projects/#{firebase_project_id}/messages:send",
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type"  => "application/json"
      }
    )

    payload = {
      message: {
        token: fcm_token,
        notification: {
          title: title,
          body: body
        },
        data: data.transform_values(&:to_s)
      }
    }

    response = conn.post do |req|
      req.body = payload.to_json
    end

    Rails.logger.info("FCM Response: #{response.body}")

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("FCM Error: #{e.message}")
    nil
  end

  private

  def self.fetch_access_token
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(Rails.root.join("config/firebase/google-services.json")),
      scope: FIREBASE_SCOPE
    )
    authorizer.fetch_access_token!["access_token"]
  end

  def self.firebase_project_id
    @firebase_project_id ||= begin
      json = JSON.parse(File.read(Rails.root.join("config/firebase/google-services.json")))
      json["project_id"]
    end
  end
end

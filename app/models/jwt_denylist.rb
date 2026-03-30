# app/models/jwt_denylist.rb
class JwtDenylist < ApplicationRecord
  def self.revoke!(jti, exp)
    create!(jti: jti, exp: Time.zone.at(exp))
  rescue ActiveRecord::RecordNotUnique
    # already revoked — ignore
  end

  def self.revoked?(jti)
    exists?(jti: jti)
  end

  # run daily via cron to keep table clean
  def self.cleanup!
    where('exp < ?', Time.zone.now).delete_all
  end
end

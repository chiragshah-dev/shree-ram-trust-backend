# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# ── Create Admin User ────────────────────────────────────
admin = User.find_or_initialize_by(phone_number: '+919999999999')

if admin.new_record?
  admin.assign_attributes(
    name:                  'Super Admin',
    password:              'Admin@123',
    password_confirmation: 'Admin@123',
    role:                  :admin,
    active:                true
  )
  if admin.save
    puts "✅ Admin created → phone: +919999999999 | password: Admin@123"
  else
    puts "❌ Admin creation failed: #{admin.errors.full_messages.join(', ')}"
  end
else
  puts "ℹ️  Admin already exists → #{admin.phone_number}"
end

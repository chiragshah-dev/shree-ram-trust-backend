module ResponseHandler
  extend ActiveSupport::Concern

  def success_response(message: nil, data: {}, status: :ok)
    render json: {
      success: true,
      message: message,
      data: data
    }, status: status
  end

  def error_response(message: nil, errors: {}, status: :unprocessable_entity)
    render json: {
      success: false,
      message: message,
      errors: errors
    }, status: status
  end
end

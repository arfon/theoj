module ControllerSpecHelpers

  def authenticate(user=nil)
    if user.is_a?(Symbol)
      user = create(user)
    elsif user.nil?
      user = create(:user)
    end
    allow(controller).to receive(:current_user).and_return(user)
    user
  end

  def response_json
    @response_json ||= JSON.parse( response.body )
  end

end
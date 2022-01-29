class Api::BaseController < ApplicationController
  skip_before_action :ensure_user_is_logged_in
end

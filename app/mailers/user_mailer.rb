class UserMailer < ApplicationMailer

  def registration
    @user = params[:user]
    @activation_link =
      "https://www.openode.io/activate/#{@user.id}/#{@user.activation_hash}"

    mail(to: @user.email, subject: 'Welcome to opeNode!')
  end

end

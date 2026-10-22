class UserMailer < ApplicationMailer
  def email_verification(user)
    @user = user

    mail(
      to: @user.email,
      subject: "Verify your TaskFlow account"
    )
  end

  def password_reset(user)
  @user = user

  mail(
    to: @user.email,
    subject: "Reset your TaskFlow password"
  )
end

  def task_assigned(task)
    @task = task
    @user = task.user
    @project = task.project

    mail(
      to: @user.email,
      subject: "New task assigned: #{@task.title}"
    )
  end

end
class TaskMailer < ApplicationMailer
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
Rails.application.routes.draw do
  # ---------- Authentication (Devise) ----------
  devise_for :users,
    path: "",
    path_names: {
      sign_in: "login",
      sign_out: "logout",
      password: "forgot-password",
      confirmation: "verification",
      registration: "register"
    }

  # Health check for load balancers / uptime monitors
  get "up" => "rails/health#show", as: :rails_health_check
  
  devise_scope :user do
    root to: "devise/sessions#new"
  end

  # ---------- Dashboard ----------
  get "dashboard", to: "dashboard#index", as: :dashboard

  # ---------- Projects ----------
  get    "/projects",             to: "projects#index"
  get    "/projects/new",         to: "projects#new"
  post   "/projects",             to: "projects#create"
  get    "projects/:id",          to: "projects#show",    as: :project
  get    "projects/:id/edit",     to: "projects#edit",    as: :edit_project
  patch  "projects/:id",          to: "projects#update"
  delete "projects/:id",          to: "projects#destroy"

  # ---------- Tasks (nested under projects) ----------
  get    "projects/:project_id/tasks/new",      to: "tasks#new",     as: :new_project_task
  post   "projects/:project_id/tasks",          to: "tasks#create",  as: :project_tasks
  get    "projects/:project_id/tasks/:id/edit", to: "tasks#edit",    as: :edit_project_task
  patch  "projects/:project_id/tasks/:id",      to: "tasks#update",  as: :project_task
  delete "projects/:project_id/tasks/:id",      to: "tasks#destroy", as: :delete_project_task

  # ---------- Project members ----------
  post   "projects/:project_id/memberships",     to: "memberships#create",  as: :project_memberships
  delete "projects/:project_id/memberships/:id", to: "memberships#destroy", as: :project_membership

  # ---------- Kanban board ----------
  get   "projects/:project_id/board",          to: "boards#show", as: :project_board
  patch "projects/:project_id/tasks/:id/move", to: "tasks#move",  as: :move_project_task

    # ---------- Calendar ----------
  get "projects/:project_id/calendar", to: "calendars#project", as: :project_calendar
  get "/my_calendar",                  to: "calendars#mine",    as: :my_calendar

  # ---------- My tasks ----------
  get   "/my_tasks",            to: "tasks#my_tasks",         as: :my_tasks
  patch "/my_tasks/:id/status", to: "tasks#update_my_status", as: :update_my_status

  # ---------- Users ----------
  get    "users",          to: "users#index",   as: :users
  get    "users/new",      to: "users#new",     as: :new_user
  post   "users",          to: "users#create"
  get    "users/:id",      to: "users#show",    as: :user
  get    "users/:id/edit", to: "users#edit",    as: :edit_user
  patch  "users/:id",      to: "users#update"
  delete "users/:id",      to: "users#destroy"
  delete "users/:user_id/avatar", to: "avatars#destroy", as: :user_avatar

  # ---------- Admin ----------
  get  "/admin",           to: "admin#index",       as: :admin_dashboard
  get  "/admin/users/new", to: "admin_users#new",   as: :new_admin_user
  post "/admin/users",     to: "admin_users#create", as: :admin_users
end
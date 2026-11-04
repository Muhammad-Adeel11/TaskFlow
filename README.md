# TaskFlow — Task & Project Management System

A full-stack, role-based task management web application built with **Ruby on Rails 8**. TaskFlow lets teams organise work into projects, assign tasks to members, track progress on a Kanban board and calendar, and monitor everything through role-specific dashboards with statistics and charts.

![Ruby](https://img.shields.io/badge/Ruby-4.0.7-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)
![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Roles and Permissions](#roles-and-permissions)
- [Data Model](#data-model)
- [Getting Started](#getting-started)
- [Creating the First Admin](#creating-the-first-admin)
- [Email in Development](#email-in-development)
- [Project Structure](#project-structure)
- [Key Routes](#key-routes)
- [Security Notes](#security-notes)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

### Authentication and accounts
- Sign up, sign in and sign out with **Devise**, using clean custom URLs (`/login`, `/register`, `/forgot-password`, `/verification`).
- **Email confirmation** for new accounts and **password reset** by email.
- "Remember me" sessions.
- Profile management: name, email, password and **profile photo** (Active Storage, PNG/JPG/WEBP/GIF up to 2 MB, with server-side validation).

### Projects and tasks
- Full CRUD for projects and tasks.
- Tasks have a title, description, status (`pending`, `in_progress`, `completed`), due date, assignee and project.
- **Email notification** to a user when a task is assigned to them.
- **My Tasks** page where each user sees and updates the status of their own tasks.
- **Project members** (memberships) to control who works on which project.

### Views and planning
- **Kanban board** per project with drag-and-drop between status columns (Stimulus sortable controller).
- **Calendar views**: per-project and personal (`simple_calendar`).
- **PDF export** of a project report (Prawn).

### Dashboards and analytics
- **Admin dashboard**: user, role, project and task totals; users-by-role and task-status donut charts; new users in the last 7 days; project progress; workload per user; recent users, projects and tasks.
- **Manager dashboard**: completion rate, overdue and unassigned tasks, tasks created per day, project progress, workload, upcoming deadlines.
- Charts are built with pure CSS and SVG (no JavaScript chart library), so they are fast and accessible.

### Search, filtering and pagination
- Search and filters powered by **Ransack** (for example users by name, email, role and confirmation state; tasks by status and due date).
- Pagination with **Kaminari**.

### Interface
- Responsive "liquid glass" design with a light theme and a **dark mode** toggle (Stimulus theme controller).
- Role-aware navigation and flash messages.

---

## Tech Stack

| Layer | Technology |
| --- | --- |
| Language / Framework | Ruby 4.0.7, Ruby on Rails 8.1 |
| Database | SQLite 3 |
| Authentication | Devise 5 (database authenticatable, registerable, recoverable, rememberable, validatable, confirmable) |
| Authorization | Pundit policies and role checks |
| Search / Filtering | Ransack |
| Pagination | Kaminari |
| PDF generation | Prawn, prawn-table |
| Calendar | simple_calendar |
| File uploads | Active Storage (local disk service) |
| Frontend | Hotwire (Turbo and Stimulus), Importmap, Propshaft, hand-written CSS |
| Background / cache | Solid Queue, Solid Cache, Solid Cable |
| Config | dotenv-rails |
| Email (development) | Mailtrap sandbox SMTP |
| Code quality / security | RuboCop (Rails Omakase), Brakeman, bundler-audit |

---

## Roles and Permissions

| Capability | User | Manager | Admin |
| --- | :---: | :---: | :---: |
| Sign up, sign in, edit own profile and photo | ✅ | ✅ | ✅ |
| View and update own assigned tasks | ✅ | ✅ | ✅ |
| Manager dashboard, create and manage projects and tasks | — | ✅ | ✅ |
| Admin dashboard and statistics | — | — | ✅ |
| View, add, edit and delete other users, change roles | — | — | ✅ |

New accounts start with the `user` role. After sign-in, admins land on the admin dashboard, managers on the manager dashboard and users on their projects.

---

## Data Model

```
User ──< Membership >── Project
 │                        │
 └────────< Task >────────┘
```

- **User**: name, email, role (`admin` / `manager` / `user`), Devise fields, one attached avatar.
- **Project**: name, description.
- **Membership**: joins users and projects.
- **Task**: title, description, status, due date, belongs to a project and optionally to a user (assignee).

---

## Getting Started

### Prerequisites

- Ruby **4.0.7** (see `.ruby-version`)
- Bundler
- SQLite 3
- Git

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/YOUR-USERNAME/task_management_app.git
cd task_management_app

# 2. Install gems
bundle install

# 3. Create your environment file from the template
cp .env.example .env          # Windows PowerShell: Copy-Item .env.example .env
# then open .env and fill in your Mailtrap credentials

# 4. Create and migrate the database
bin/rails db:create db:migrate

# 5. Start the server
bin/rails server
```

Open **http://localhost:3000**.

### Running the checks

```bash
bin/rails test            # test suite
bin/rubocop               # style
bin/brakeman              # security scan
bin/bundler-audit         # vulnerable gems
```

---

## Creating the First Admin

Sign-ups always receive the `user` role, so promote your first account from the Rails console:

```bash
bin/rails console
```

```ruby
user = User.find_by(email: "you@example.com")
user.confirm                      # skip the email confirmation step
user.update!(role: "admin")
```

After that, sign in and use the **Admin Dashboard** to add other users and managers.

---

## Email in Development

Emails (account confirmation, password reset, task assignment) are delivered to a **Mailtrap sandbox inbox**, not to real addresses. Create a free inbox at [mailtrap.io](https://mailtrap.io), copy its SMTP credentials into `.env`:

```
MAILTRAP_USERNAME=your_username
MAILTRAP_PASSWORD=your_password
```

and read the messages in the Mailtrap web inbox.

---

## Project Structure

```
app/
├── controllers/      Projects, Tasks, Users, Dashboard, Admin, Boards, Calendars, Memberships, Avatars
├── models/           User, Project, Task, Membership, DashboardStats
├── policies/         Pundit policies (project, task)
├── mailers/          TaskMailer (task assignment), UserMailer
├── helpers/          Dashboard and avatar helpers
├── javascript/controllers/   Stimulus: sortable (Kanban), theme (dark mode)
└── views/            ERB templates, shared chart partials (donut, bars, columns)
config/
├── routes.rb         Custom Devise paths and RESTful resources
└── environments/     Environment configuration
db/
├── migrate/          Schema migrations
└── schema.rb
```

---

## Key Routes

| Path | Purpose |
| --- | --- |
| `/login`, `/register`, `/forgot-password`, `/verification` | Authentication (Devise) |
| `/dashboard` | Manager dashboard |
| `/admin` | Admin dashboard |
| `/projects`, `/projects/:id` | Projects |
| `/projects/:id.pdf` | Project PDF report |
| `/projects/:project_id/board` | Kanban board |
| `/projects/:project_id/calendar`, `/my_calendar` | Calendars |
| `/my_tasks` | Tasks assigned to the current user |
| `/users`, `/users/:id`, `/users/:id/edit` | User management and profiles |
| `/up` | Health check |

---

## Security Notes

- Secrets live in `.env` (ignored by Git). Never commit credentials; `.env.example` documents the variables.
- Passwords are hashed by Devise (bcrypt); accounts require email confirmation.
- Access is enforced with role checks and Pundit policies.
- Uploaded avatars are validated for type and size.
- `config/*.key` and uploaded files in `storage/` are ignored by Git.
- Run `bin/brakeman` and `bin/bundler-audit` before releases.

---

## Roadmap

- Cloud file storage for production uploads (Amazon S3 or Google Cloud Storage).
- Image thumbnails with libvips.
- Task comments and file attachments.
- In-app notifications.
- Deployment with Kamal / Docker.

---

## License

Released under the [MIT License](LICENSE).

---

## Author

**Your Name** — [GitHub](https://github.com/YOUR-USERNAME) · [LinkedIn](https://www.linkedin.com/in/your-profile)

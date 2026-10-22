module ApplicationHelper
  # true when the user has filled in any filter (the sort field "s" is ignored)
  def filters_active?
    q = params[:q]
    q.respond_to?(:except) && q.except(:s).values.any?(&:present?)
  end

  def user_avatar(user, size: 40)
    style = "width: #{size}px; height: #{size}px; font-size: #{(size * 0.42).round}px;"

    if user.avatar.attached?
      image_tag url_for(user.avatar), alt: user.name.to_s, class: "avatar", style: style, loading: "lazy"
    else
      content_tag :span, user.name.to_s.first.to_s.upcase, class: "avatar avatar-initial", style: style
    end
  end

    # Navigation link that is highlighted when you are on that section
  def nav_link(label, path, exact: false)
    active = exact ? request.path == path : (request.path == path || request.path.start_with?("#{path}/"))

  link_to label, path,
    class: ["nav-link", ("is-active" if active)],
    aria: { current: (active ? "page" : nil) }
  end
end
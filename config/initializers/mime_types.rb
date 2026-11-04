unless Mime::Type.lookup_by_extension(:xlsx)
  Mime::Type.register "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :xlsx
end
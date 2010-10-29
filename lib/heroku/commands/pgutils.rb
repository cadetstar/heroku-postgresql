module PgUtils
  def spinner(ticks)
    %w(/ - \\ |)[ticks % 4]
  end

  def redisplay(line, line_break = false)
    display("\r\e[0K#{line}", line_break)
  end

  def display_info(label, info)
    display(format("%-12s %s", label, info))
  end

  def pg_config_var_names
    # all config vars that are a postgres:// URL
    pg_config_vars = @config_vars.reject { |k,v| not v =~ /^postgres:\/\// }
    pg_config_vars.keys.sort!
  end

  def resolve_db_id(input, opts={})
    name = input || opts[:default]

    # try to find addon config var name from all config vars
    # if name is 'DATABASE_URL', try to return the addon config var name for better accounting
    output = nil
    addon_config_vars = pg_config_var_names - ["DATABASE_URL"]
    addon_config_vars.each do |n|
      next unless @config_vars[n] == @config_vars[name]
      return n, @config_vars[n]
    end

    # database url isn't an alias for another var
    return name, @config_vars[name] if name == "DATABASE_URL"

    if name
      display " !   Database #{name} not found in config."
    else
      display " !   This command requires a database to operate on."
    end
    display " !   "
    display " !   Available database URLs:"
    addon_config_vars.each do |v|
      str = " !   #{v}"
      str += " (currently DATABASE_URL)" if @config_vars[v] == @config_vars["DATABASE_URL"]
      display str
    end
    abort ""
  end

end

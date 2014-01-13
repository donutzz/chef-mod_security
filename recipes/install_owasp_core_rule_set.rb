
package "tar" do
  action :install
end

directory "#{node[:mod_security][:crs][:rules_root_dir]}" do
  recursive true
end
directory "#{node[:mod_security][:crs][:files]}" do
  recursive true
end

# install tarfile
tarfile = "#{node[:mod_security][:crs][:files]}/#{node[:mod_security][:crs][:file_name]}"
remote_file tarfile do
    action :create_if_missing
    source node[:mod_security][:crs][:dl_url]
    mode "0644"
    #checksum node[:mod_security][crs][:checksum] seems to get ignored? FIXME
    backup false
end

# untar core rule set if tarfile is updated
execute "unzip_core_rule_set" do
  command "tar -xzf #{tarfile} -C #{node[:mod_security][:crs][:rules_root_dir]}"
  action :nothing
  subscribes :run, resources(:remote_file => tarfile), :immediately
end

# install settings config
# - currently heavily tied to version of crs. be wary of updating one
# - without the other
template "#{node[:mod_security][:crs][:rules_root_dir]}/modsecurity_crs_10_config.conf" do
  mode "0644"
  notifies :restart, resources(:service => "apache2"), :delayed
end

node[:mod_security][:crs][:rules].each_pair do |rule_group,rules|
  rule_dir = "#{node[:mod_security][:crs][:rules_root_dir]}/#{rule_group}_rules"
  rules.each_pair do |rule,flag|
    link "#{node[:mod_security][:crs][:activated_rules]}/#{rule}.conf" do
      to "#{rule_dir}/#{rule}.conf"
      action (flag ? :create : :delete )
      notifies :restart, resources(:service => "apache2"), :delayed
    end

    # deal with data_files
    data_filename = case rule
    when "modsecurity_crs_35_bad_robots"
      "modsecurity_35_scanners.data"
    when "modsecurity_crs_50_outbound"
      "modsecurity_50_outbound_malware.data"
    when "modsecurity_crs_46_slr_et_joomla_attacks"
      "modsecurity_46_slr_et_joomla.data"
    when "modsecurity_crs_46_slr_et_lfi_attacks"
      "modsecurity_46_slr_et_lfi.data"
    when "modsecurity_crs_46_slr_et_phpbb_attacks"
      "modsecurity_46_slr_et_phpbb.data"
    when "modsecurity_crs_46_slr_et_rfi_attacks"
       "modsecurity_46_slr_et_rfi.data"
    when "modsecurity_crs_46_slr_et_wordpress_attacks"
       "modsecurity_46_slr_et_wordpress.data"
    when "modsecurity_crs_46_slr_et_xss_attacks"
       "modsecurity_46_slr_et_xss.data"
    when "modsecurity_crs_46_slr_et_sqli_attacks"
      "modsecurity_46_slr_et_sqli.data"
    else
      # why does the crs disappear from the data filenames? why!?
      "#{rule.gsub(/crs_/,'')}.data"
    end 
    
    link "#{node[:mod_security][:crs][:activated_rules]}/#{data_filename}" do
      to "#{rule_dir}/#{data_filename}"
      action (flag ? :create : :delete )
      only_if "test -e #{rule_dir}/#{data_filename}"
      notifies :restart, resources(:service => "apache2"), :delayed
    end
    
  end
end 

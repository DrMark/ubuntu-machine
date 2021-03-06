namespace :machine do

  desc "Change the root password, create a new user and allow him to sudo and to SSH"
  task :initial_setup do
    set :user_to_create , user
    set :user, 'root'
    
    run_and_watch_prompt("passwd", [/Enter new UNIX password/, /Retype new UNIX password:/])
    
    run_and_watch_prompt("adduser #{user_to_create}", [/Enter new UNIX password/, /Retype new UNIX password:/, /\[\]\:/, /\[y\/N\]/i])
    
    # force the non-interactive mode
    run "cat /etc/environment > ~/environment.tmp"
    run 'echo DEBIAN_FRONTEND=noninteractive >> ~/environment.tmp'
    sudo 'mv ~/environment.tmp /etc/environment'
    # prevent this env variable to be skipped by sudo
    run "echo 'Defaults env_keep = \"DEBIAN_FRONTEND\"' >> /etc/sudoers"

    run "echo '#{user_to_create} ALL=(ALL)ALL' >> /etc/sudoers"
    run "echo 'AllowUsers #{user_to_create}' >> /etc/ssh/sshd_config"
    run "/etc/init.d/ssh reload"
  end

  task :configure do
    ssh.setup
    iptables.configure
    aptitude.setup
  end

  task :install_dev_tools do
    curl.install if install_curl
    mysql.install if install_mysql
    apache.install if install_apache
    ruby.install if install_ruby
    gems.install_rubygems if install_rubygems
    imagemagick.install if install_imagemagick
    ruby.install_enterprise if install_ruby_enterprise
    ruby.install_passenger if install_passenger
    git.install if install_git
    php.install if install_php
    sphinx.install if install_sphinx
    apparmor.configure if configure_apparmor
  end

  desc = "Ask for a user and change his password"
  task :change_password do
    user_to_update = Capistrano::CLI.ui.ask("Name of the user whose you want to update the password : ")

    sudo "passwd #{user_to_update}", :pty => true do |ch, stream, data|
      if data =~ /Enter new UNIX password/ || data=~ /Retype new UNIX password:/
        # prompt, and then send the response to the remote process
        ch.send_data(Capistrano::CLI.password_prompt(data) + "\n")
      else
        # use the default handler for all other text
        Capistrano::Configuration.default_io_proc.call(ch, stream, data)
      end
    end
  end
end

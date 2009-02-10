namespace :machine do

  desc "Change the root password, create a new user and allow him to sudo and to SSH"
  task :initial_setup do
    set :user_to_create , user
    username = Capistrano::CLI.ui.ask("Username to login as (#{root_user}) : ")
    set :user, (username.nil? || username.empty?) ? root_user : username
    puts "-- logging in as #{user}"
    run "whoami"
    sure = Capistrano::CLI.ui.ask("Change the password for #{user}? (y/N) : ")
    if sure.to_s.strip.downcase == 'y'
      run "passwd", :pty => true do |ch, stream, data|
        if data =~ /UNIX password/
          # prompt, and then send the response to the remote process
          ch.send_data(Capistrano::CLI.password_prompt(data) + "\n")
        else
          # use the default handler for all other text
          Capistrano::Configuration.default_io_proc.call(ch, stream, data)
        end
      end
    end

    users = capture('cat /etc/passwd | cut -d":" -f1').split(/\s+/)
    if users.include?(user_to_create)
      puts "-- user: #{user_to_create.inspect} already exists."
    else
      sudo "adduser #{user_to_create}", :pty => true do |ch, stream, data|
        if data =~ /UNIX password/ || data=~/\[\]\:/ || data=~/\[y\/N\]/i
          # prompt, and then send the response to the remote process
          ch.send_data(Capistrano::CLI.password_prompt(data) + "\n")
        else
          # use the default handler for all other text
          Capistrano::Configuration.default_io_proc.call(ch, stream, data)
        end
      end
    end

    sudoers_file = capture("cat /etc/sudoers", :via => :sudo)
    if sudoers_file.include? "#{user_to_create} ALL=(ALL)ALL"
      puts "-- #{user_to_create} is already a sudoer"
    else
      sudo" bash -c \"echo '#{user_to_create} ALL=(ALL)ALL' >> /etc/sudoers\""
      if setup_ssh
        #this next line effectively prevents the root user from ssh access by only allowing the new user
        sudo" bash -c \"echo 'AllowUsers #{user_to_create}' >> /etc/ssh/sshd_config\""
        sudo "/etc/init.d/ssh reload"
      end
    end
  end

  task :configure do
    ssh.setup
    iptables.configure
    aptitude.setup
  end

  task :install_dev_tools do
    curl.install
    mysql.install
    apache.install
    ruby.install
    gems.install_rubygems
    ruby.install_enterprise
    ruby.install_passenger
    git.install
    php.install
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

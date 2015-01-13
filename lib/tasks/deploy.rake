require "io/console"

namespace :deploy do
  # Constants
  PURPLE = "\e[0;35m"
  WHITE = "\e[1;37m"
  YELLOW = "\e[0;33m"
  BLUE = "\e[0;34m"
  DEFAULT_COLOR = "\e[0m"

  DIVIDER = "\n#{ PURPLE } ======================================" \
            "==========================\e[0m\n"
  DIVIDER_BLUE = "\n#{ BLUE } =================================" \
            "===============================\e[0m\n"

  current_tag = ""
  new_tag = ""
  current_tag_date = ""
  current_major = 0
  current_minor = 0
  current_patch = 0

  desc "Create a new tag"
  task :tag do

    puts DIVIDER
    puts "#{ PURPLE } *** #{ WHITE }Welcome to git_tagger"\
    "!#{ DEFAULT_COLOR } #{ PURPLE } ***#{ DEFAULT_COLOR }"
    puts DIVIDER

    tag_list = `git tag | gsort -V`
    if tag_list
      current_tag = tag_list.split("\n").last
      current_tag_date = `git log --tags --simplify-by-decoration --pretty="format:%ai" -n 1`
    else
      current_tag = "0.0.0"
      current_tag_date = "2015-01-01 00:00:00 -0600"
    end

    current_major = current_tag.split(".")[0].to_i
    current_minor = current_tag.split(".")[1].to_i
    current_patch = current_tag.split(".")[2].to_i

    Rake::Task["deploy:retrieve_tag_type"].invoke
    Rake::Task["deploy:create_change_log"].invoke
    Rake::Task["deploy:create_and_push_tag"].invoke
  end

  desc "Choose a tag type"
  task :retrieve_tag_type do
    puts ""
    puts "#{ YELLOW } - MAJOR#{ DEFAULT_COLOR } version when you make"\
    " incompatible API changes."
    puts "#{ YELLOW } - MINOR#{ DEFAULT_COLOR } version when you add "\
    "functionality in a backwards-compatible manner"
    puts "#{ YELLOW } - PATCH#{ DEFAULT_COLOR } version when you make"\
    " backwards-compatible bug fixes."
    puts ""
    puts "\e[0;31m Type the letter indicating the tag update type "
    print " #{ DEFAULT_COLOR }#{ YELLOW }MAJOR(#{ DEFAULT_COLOR }#{ WHITE }"\
    "M#{ YELLOW }), #{ YELLOW }MINOR(#{ DEFAULT_COLOR }#{ WHITE }m#{ YELLOW }"\
    "), #{ YELLOW }PATCH(#{ DEFAULT_COLOR }#{ WHITE }p#{ YELLOW }), "\
    "#{ YELLOW }QUIT(#{ DEFAULT_COLOR }#{ WHITE }q#{ YELLOW }) (#{ WHITE }"\
    "M#{ YELLOW }/#{ WHITE }m#{ YELLOW }/#{ WHITE }p#{ YELLOW }/#{ WHITE }q"\
    "#{ YELLOW }): #{ DEFAULT_COLOR }"

    input = ""
    Kernel.loop do
      input = STDIN.getch
      break if !input || %(m p q M).include?(input)
    end

    puts input

    case input
    when "p"
      current_patch += 1
    when "m"
      current_minor += 1
      current_patch = 0
    when "M"
      current_major += 1
      current_minor = 0
      current_patch = 0
    when "q"
      abort("Aborting tag procedure")
    end

    puts ""
    puts " The current tag is: [#{ current_tag }]"
    puts " Updating tag to be: [#{current_major}.#{current_minor}."\
    "#{current_patch}]"
    puts ""

    if confirm " #{ YELLOW }Is this correct? (#{WHITE}y#{YELLOW}/#{WHITE}n"\
    "#{YELLOW}) "
      new_tag = "#{current_major}.#{current_minor}.#{current_patch}"
    else
      abort("Aborting tag procedure")
    end
  end

  desc "Create a changelog entry and commit to master"
  task :create_change_log do
    if confirm " Would you like to create and commit a changelog message " \
    "related to your new tag? (y/n)"
      puts ""
      puts " The following commits were made since the last tag was created"
      puts DIVIDER_BLUE
      print `git log --since="#{ current_tag_date }" --pretty=format:'%Cblue %ci %Creset-%Cred %an%Creset - %s'`
      puts DIVIDER_BLUE
      puts " #{ YELLOW }Enter a brief changelog message to describe the " \
      "updates since the last tag was created, then press [#{WHITE}ENTER" \
      "#{YELLOW}]#{DEFAULT_COLOR}"
      changelog_message = STDIN.gets.strip
      puts ""
      puts "#{ YELLOW } The following will be prefixed to the CHANGELOG.md " \
      "file #{DEFAULT_COLOR}"
      puts "## #{ new_tag } - #{ DateTime.now.strftime('%F') }"
      puts " * #{ changelog_message }"
      puts ""
      complete_changelog_update = "## #{ new_tag } - " \
      "#{ DateTime.now.strftime('%F') }\n * #{ changelog_message }\n\n"

      if confirm "#{ YELLOW } Are you sure that you would like to commit " \
      "this change to origin/master before creating the new tag? (#{WHITE}y" \
      "#{YELLOW}/#{WHITE}n#{YELLOW})#{DEFAULT_COLOR} "
        modify_changelog(complete_changelog_update)
        `git add -A`
        `git commit -m "Updating changelog for latest tag."`
      else
        abort("Aborting tagging process.")
      end
    end
  end

  desc "Create and push new tag"
  task :create_and_push_tag do
    puts "Creating and pushing new tag..."
    `git tag #{ new_tag }`
    `git push origin #{ new_tag }`
    puts "#{ WHITE }Tag creation complete! #{ DEFAULT_COLOR }"
  end

  def confirm(question)
    print question
    confirmation = ""
    Kernel.loop do
      confirmation = STDIN.getch
      break if !confirmation || %(y n).include?(confirmation)
    end

    puts confirmation
    puts DIVIDER
    "y" == confirmation
  end

  def modify_changelog(message)
    if defined? Rails
      original_changelog = File.expand_path(Rails.root.join "CHANGELOG.md")
    else
      original_changelog = File.join(File.dirname(File.expand_path(__FILE__)), "../../CHANGELOG.md")
    end

    new_changelog = "#{original_changelog}.new"
    File.open(new_changelog, "w") do |fo|
      fo.puts message
      File.foreach(original_changelog) do |li|
        fo.puts li
      end
    end
    File.rename(new_changelog, original_changelog)
  end
end

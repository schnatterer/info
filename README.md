# schnatterer.info

## Build

```bash
# Install ruby
sudo apt-get install ruby-full build-essential zlib1g-dev
# Install gems for local user
echo '# Install Ruby Gems to ~/gems' >> ~/.zshrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.zshrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Download dependencies
bundle install 
# Start jekyll development server with client-side live-reload
bundle exec jekyll serve --livereload
```
# puml-ld Installation Guide

## Prerequisites

- Ruby 3.3.6
- Bundler gem
- Linux, macOS, or Windows with WSL

## Installation Steps

### 1. Install Ruby 3.3.6

#### Using rbenv (Recommended)

```bash
# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Add rbenv to your shell
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.3.6
rbenv install 3.3.6
rbenv global 3.3.6

# Verify installation
ruby --version
# Should output: ruby 3.3.6 (2024-11-05 revision 75015d4c1f) [x86_64-linux]
```

#### Using RVM (Alternative)

```bash
# Install RVM
\curl -sSL https://get.rvm.io | bash -s stable

# Load RVM
source ~/.rvm/scripts/rvm

# Install Ruby 3.3.6
rvm install 3.3.6
rvm use 3.3.6 --default

# Verify installation
ruby --version
```

### 2. Install Dependencies

```bash
cd puml-ld
gem install bundler
bundle install
```

This will install all required gems:
- sinatra (~> 4.1)
- rdf (~> 3.3)
- json-ld (~> 3.3)
- rackup (~> 2.2)
- puma (~> 6.5)
- rspec (~> 3.13) [development/test]
- rack-test (~> 2.1) [development/test]
- cucumber (~> 9.2) [development/test]

### 3. Verify Installation

```bash
# Check Ruby syntax
ruby -c app.rb

# Run manual test
ruby test_manual.rb
```

## Running the Application

### Start the Server

```bash
bundle exec rackup -p 4567
```

The application will be available at `http://localhost:4567`

### Alternative: Using Puma Directly

```bash
bundle exec puma -p 4567
```

### Running in Background

```bash
bundle exec rackup -p 4567 > server.log 2>&1 &
```

### Stopping the Server

```bash
# If running in foreground: Press Ctrl+C

# If running in background:
pkill -f rackup
# or
pkill -f puma
```

## Testing the Installation

### 1. Check Health Endpoint

```bash
curl http://localhost:4567/health
```

Expected response:
```json
{"status":"ok","timestamp":"2025-12-11T14:00:00-05:00"}
```

### 2. Test SHACL Endpoint

```bash
curl "http://localhost:4567/shacl?name=Class"
```

Expected response: Turtle format SHACL shape definition

### 3. Test Convert Endpoint

```bash
curl -X PUT http://localhost:4567/convert \
  -H 'Context: {"@vocab": "http://example.org/uml#"}' \
  -H "Id: http://example.org/diagrams/test" \
  --data '@startuml
class Person
@enduml'
```

Expected response: JSON-LD document

## Troubleshooting

### Port Already in Use

If you see "Address already in use" error:

```bash
# Find process using port 4567
lsof -i :4567

# Kill the process
kill -9 <PID>

# Or use a different port
bundle exec rackup -p 4568
```

### Missing Dependencies

If you see gem-related errors:

```bash
bundle install --verbose
```

### Ruby Version Mismatch

If you see Ruby version errors:

```bash
rbenv local 3.3.6
bundle install
```

### Permission Errors

If you see permission errors:

```bash
# Don't use sudo with rbenv/rvm
# Instead, ensure proper ownership
chown -R $USER:$USER ~/.rbenv
```

## Development Setup

### Running Tests

```bash
# Run RSpec tests
bundle exec rspec

# Run Cucumber tests
bundle exec cucumber
```

### Code Validation

```bash
# Check Ruby syntax
ruby -c app.rb
ruby -c lib/*.rb

# Run manual tests
ruby test_manual.rb
```

## Production Deployment

### Using Systemd (Linux)

Create `/etc/systemd/system/puml-ld.service`:

```ini
[Unit]
Description=puml-ld Service
After=network.target

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/puml-ld
Environment="PATH=/home/your_user/.rbenv/shims:/home/your_user/.rbenv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/your_user/.rbenv/shims/bundle exec rackup -p 4567
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable puml-ld
sudo systemctl start puml-ld
sudo systemctl status puml-ld
```

### Using Docker

Create `Dockerfile`:

```dockerfile
FROM ruby:3.3.6-slim

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "-p", "4567", "-o", "0.0.0.0"]
```

Build and run:

```bash
docker build -t puml-ld .
docker run -p 4567:4567 puml-ld
```

## Configuration

### Environment Variables

- `PORT`: Server port (default: 4567)
- `RACK_ENV`: Environment (development/production)

### Custom Port

```bash
PORT=8080 bundle exec rackup
```

### Production Mode

```bash
RACK_ENV=production bundle exec rackup -p 4567
```

## Support

For issues and questions:
- Check the README.md for API documentation
- Review examples in examples/ directory
- Check server logs for error messages

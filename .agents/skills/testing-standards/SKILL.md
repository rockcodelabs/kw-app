---
name: testing-standards
description: kw-app testing standards using RSpec, FactoryBot, and Docker. Covers test types, patterns, and best practices for TDD workflow.
allowed-tools: Read, Write, Edit, Bash
---

# Testing Standards (kw-app)

## Overview

**Test Framework**: RSpec 3.x  
**Fixtures**: FactoryBot  
**Environment**: Docker (MANDATORY)  
**Philosophy**: TDD (RED → GREEN → REFACTOR)

## Test Environment

### CRITICAL: Always Use Docker

```bash
# ✅ Correct - Run tests in Docker
docker-compose exec -T app bundle exec rspec

# ❌ Wrong - Don't run on host
bundle exec rspec  # Wrong Ruby version, no PostgreSQL/Redis
```

**Why Docker is mandatory:**
- Host Ruby (2.6.10) ≠ App Ruby (3.2.11)
- Tests need PostgreSQL 10.3 and Redis 7 from containers
- Exact gem versions from container's bundle
- Consistent with CI environment

## Test Commands

### Basic Commands

```bash
# All tests
docker-compose exec -T app bundle exec rspec

# Specific file
docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb

# Specific line
docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb:25

# Pattern match
docker-compose exec -T app bundle exec rspec spec/models/

# Verbose output (debugging)
docker-compose exec -T app env VERBOSE_TESTS=true bundle exec rspec

# Fast fail (stop on first failure)
docker-compose exec -T app bundle exec rspec --fail-fast

# Documentation format
docker-compose exec -T app bundle exec rspec --format documentation
```

### Interactive Console

```bash
# Rails console (for debugging tests)
docker-compose exec app bundle exec rails console
```

## Test Types & Structure

### Directory Structure

```
spec/
├── models/              # Model specs (validations, associations, scopes)
├── components/          # Service object / operation specs
│   └── users/
│       └── operation/
│           └── create_spec.rb
├── requests/            # HTTP integration tests (PREFERRED over controller specs)
├── factories/           # FactoryBot factories
├── support/             # Shared contexts, helpers
│   ├── factory_bot.rb
│   ├── database_cleaner.rb
│   └── shared_examples/
└── rails_helper.rb      # Main test configuration
```

### Test Type Selection

| What to Test | Test Type | Example |
|--------------|-----------|---------|
| Model validations | Model spec | `spec/models/user_spec.rb` |
| Service objects | Component spec | `spec/components/users/operation/create_spec.rb` |
| HTTP endpoints | Request spec | `spec/requests/users_spec.rb` |
| Background jobs | Job spec | `spec/jobs/user_notification_job_spec.rb` |
| Mailers | Mailer spec | `spec/mailers/user_mailer_spec.rb` |

**Don't write:**
- ❌ Controller specs (use request specs instead)
- ❌ View specs (use request specs or system specs)
- ❌ Helper specs (extract logic to models/services)

## Model Specs

### Structure

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:posts) }
    it { should belong_to(:company) }
  end

  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_user) { create(:user, active: true) }
      let!(:inactive_user) { create(:user, active: false) }

      it 'returns only active users' do
        expect(User.active).to contain_exactly(active_user)
      end
    end
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'combines first and last name' do
      expect(user.full_name).to eq('John Doe')
    end
  end
end
```

### Model Best Practices

- ✅ Use `build(:user)` for validation tests (no DB hit)
- ✅ Use `create(:user)` when testing associations/scopes
- ✅ Test one thing per example
- ✅ Use `subject` for repeated objects
- ✅ Group related tests with `describe` or `context`

## Service Object Specs (dry-monads)

### Structure

```ruby
# spec/components/users/operation/create_spec.rb
require 'rails_helper'

RSpec.describe Users::Operation::Create do
  subject(:operation) { described_class.new }

  describe '#call' do
    let(:params) { { email: 'test@example.com', name: 'Test User' } }

    context 'with valid params' do
      it 'returns Success with user' do
        result = operation.call(params: params)

        expect(result).to be_success
        expect(result.success).to be_a(User)
        expect(result.success.email).to eq('test@example.com')
      end

      it 'creates a user record' do
        expect { operation.call(params: params) }
          .to change(User, :count).by(1)
      end

      it 'sends welcome email' do
        expect(UserMailer).to receive(:welcome).and_call_original

        operation.call(params: params)
      end
    end

    context 'with invalid params' do
      let(:params) { { email: '', name: '' } }

      it 'returns Failure with errors' do
        result = operation.call(params: params)

        expect(result).to be_failure
        expect(result.failure).to be_a(Hash)
        expect(result.failure).to include(:email, :name)
      end

      it 'does not create a user' do
        expect { operation.call(params: params) }
          .not_to change(User, :count)
      end
    end

    context 'with duplicate email' do
      before { create(:user, email: 'test@example.com') }

      let(:params) { { email: 'test@example.com', name: 'Other User' } }

      it 'returns Failure' do
        result = operation.call(params: params)

        expect(result).to be_failure
      end
    end
  end
end
```

### Service Spec Best Practices

- ✅ Test Success and Failure paths
- ✅ Use `be_success` and `be_failure` matchers
- ✅ Verify side effects (record creation, emails, etc.)
- ✅ Mock external services
- ✅ Test error messages when relevant

## Request Specs (HTTP Integration)

### Structure

```ruby
# spec/requests/users_spec.rb
require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'POST /users' do
    let(:valid_params) do
      { user: { email: 'test@example.com', name: 'Test User' } }
    end

    context 'with valid params' do
      it 'creates a new user' do
        expect { post users_path, params: valid_params }
          .to change(User, :count).by(1)
      end

      it 'returns 201 created' do
        post users_path, params: valid_params

        expect(response).to have_http_status(:created)
      end

      it 'returns user data' do
        post users_path, params: valid_params

        json = JSON.parse(response.body)
        expect(json['email']).to eq('test@example.com')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) { { user: { email: '', name: '' } } }

      it 'does not create a user' do
        expect { post users_path, params: invalid_params }
          .not_to change(User, :count)
      end

      it 'returns 422 unprocessable entity' do
        post users_path, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post users_path, params: invalid_params

        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post users_path, params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /users/:id' do
    let(:user) { create(:user) }

    it 'returns the user' do
      get user_path(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(user.id)
    end

    context 'when user does not exist' do
      it 'returns 404 not found' do
        get user_path(id: 99999)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

### Request Spec Best Practices

- ✅ Test full HTTP request/response cycle
- ✅ Test status codes
- ✅ Test response body (JSON)
- ✅ Test authentication/authorization
- ✅ Use `have_http_status` matcher
- ✅ Parse JSON responses for assertions

## FactoryBot Patterns

### Basic Factory

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    name { Faker::Name.name }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :with_posts do
      transient do
        posts_count { 3 }
      end

      after(:create) do |user, evaluator|
        create_list(:post, evaluator.posts_count, user: user)
      end
    end
  end
end
```

### Factory Usage

```ruby
# Basic
user = build(:user)              # Not saved
user = create(:user)             # Saved to DB

# With traits
admin = create(:user, :admin)
inactive = create(:user, :inactive)

# Override attributes
user = create(:user, email: 'specific@example.com')

# With associations
user = create(:user, :with_posts)

# Lists
users = create_list(:user, 5)
admins = create_list(:user, 3, :admin)
```

### Factory Best Practices

- ✅ Use `Faker` for random data
- ✅ Use `traits` for variations
- ✅ Use `transient` for counts
- ✅ Use `after(:create)` for associations
- ✅ Keep factories minimal (only required attributes)

## Mocking & Stubbing

### External Services

```ruby
# Stub external API call
allow(PaymentGateway).to receive(:charge).and_return(true)

# Mock with expectations
expect(UserMailer).to receive(:welcome)
  .with(user)
  .and_call_original

# Stub with specific return
allow(InventoryService).to receive(:available?)
  .with(product_id, quantity)
  .and_return(true)

# Stub to raise error
allow(PaymentGateway).to receive(:charge)
  .and_raise(PaymentGateway::Error, 'Card declined')
```

### Time & Date

```ruby
# Freeze time
freeze_time = Time.zone.parse('2024-01-15 10:00:00')
travel_to(freeze_time) do
  # Tests here see fixed time
end

# Travel forward
travel 1.day do
  # Tests see tomorrow
end
```

## Shared Examples

### Definition

```ruby
# spec/support/shared_examples/trackable.rb
RSpec.shared_examples 'trackable' do
  it { should have_db_column(:created_at).of_type(:datetime) }
  it { should have_db_column(:updated_at).of_type(:datetime) }

  describe 'timestamps' do
    let(:record) { create(described_class.name.underscore) }

    it 'sets created_at on create' do
      expect(record.created_at).to be_present
    end

    it 'updates updated_at on save' do
      original = record.updated_at
      travel 1.minute do
        record.touch
        expect(record.updated_at).to be > original
      end
    end
  end
end
```

### Usage

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  it_behaves_like 'trackable'
end
```

## TDD Workflow

### RED → GREEN → REFACTOR

```
1. RED: Write failing test
   docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb
   ❌ Test fails (expected)

2. GREEN: Write minimum code to pass
   docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb
   ✅ Test passes

3. REFACTOR: Improve code
   docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb
   ✅ Test still passes

4. Repeat
```

### Example: Adding Email Validation

```ruby
# 1. RED - Write failing test
describe 'validations' do
  it { should validate_presence_of(:email) }
end
# Run: ❌ Fails

# 2. GREEN - Add validation
class User < ApplicationRecord
  validates :email, presence: true
end
# Run: ✅ Passes

# 3. REFACTOR - Add format validation
describe 'validations' do
  it { should validate_presence_of(:email) }
  it { should allow_value('test@example.com').for(:email) }
  it { should_not allow_value('invalid').for(:email) }
end

class User < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
# Run: ✅ Still passes
```

## Coverage

### Running Coverage

```bash
# With SimpleCov
COVERAGE=true docker-compose exec -T app bundle exec rspec

# View report
open coverage/index.html
```

### Coverage Goals

- ✅ Aim for 90%+ coverage
- ✅ Focus on critical paths
- ❌ Don't obsess over 100%
- ❌ Don't test trivial code just for coverage

## Common Mistakes

### ❌ Mistake 1: Running Tests on Host

```bash
# ❌ Wrong - uses system Ruby
bundle exec rspec
```

**Fix:**
```bash
# ✅ Correct - uses Docker Ruby
docker-compose exec -T app bundle exec rspec
```

### ❌ Mistake 2: Not Using FactoryBot

```ruby
# ❌ Wrong - hardcoded data
user = User.create!(email: 'test@test.com', name: 'Test')
```

**Fix:**
```ruby
# ✅ Correct - uses factory
user = create(:user)
```

### ❌ Mistake 3: Testing Too Much in One Example

```ruby
# ❌ Wrong - multiple assertions
it 'creates user and sends email and updates counter' do
  expect { operation.call }.to change(User, :count).by(1)
  expect(UserMailer).to have_received(:welcome)
  expect(Rails.cache.read('user_count')).to eq(1)
end
```

**Fix:**
```ruby
# ✅ Correct - separate examples
it 'creates user' do
  expect { operation.call }.to change(User, :count).by(1)
end

it 'sends welcome email' do
  expect(UserMailer).to receive(:welcome)
  operation.call
end

it 'updates counter' do
  operation.call
  expect(Rails.cache.read('user_count')).to eq(1)
end
```

### ❌ Mistake 4: Not Cleaning Test Data

```ruby
# ❌ Wrong - data persists between tests
before(:all) do
  @user = create(:user)
end
```

**Fix:**
```ruby
# ✅ Correct - clean data per test
before(:each) do
  @user = create(:user)
end
```

## Quick Reference

| Task | Command |
|------|---------|
| Run all tests | `docker-compose exec -T app bundle exec rspec` |
| Run specific file | `docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb` |
| Run specific line | `docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb:25` |
| Verbose output | `docker-compose exec -T app env VERBOSE_TESTS=true bundle exec rspec` |
| Fast fail | `docker-compose exec -T app bundle exec rspec --fail-fast` |
| With coverage | `COVERAGE=true docker-compose exec -T app bundle exec rspec` |

## Additional Resources

- **RSpec Docs**: https://rspec.info/
- **FactoryBot**: https://github.com/thoughtbot/factory_bot
- **kw-app Testing Guide**: See CLAUDE.md section on testing
- **Known Issues**: docs/KNOWN_ISSUES.md

---

**Version**: 2.0  
**Last Updated**: 2024-01  
**Maintained By**: kw-app team
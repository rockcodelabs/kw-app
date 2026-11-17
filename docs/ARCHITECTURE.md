# Architecture Guide

> Complete architecture reference for kw-app. Rails 7 + dry-rb operations-based architecture.

---

## Table of Contents

1. [Overview](#overview)
2. [Layer Diagram](#layer-diagram)
3. [Directory Structure](#directory-structure)
4. [Layer Responsibilities](#layer-responsibilities)
5. [Code Patterns](#code-patterns)
6. [Dependency Injection](#dependency-injection)
7. [Naming Conventions](#naming-conventions)
8. [Data Flow Examples](#data-flow-examples)
9. [Testing Architecture](#testing-architecture)
10. [Background Jobs](#background-jobs)
11. [Migration Patterns](#migration-patterns)

---

## Overview

### Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Ruby | 3.2.11 | Language |
| Rails | 7.0.8 | Framework |
| PostgreSQL | 10.3 | Database |
| Redis | 7 | Caching, Sidekiq |
| Sidekiq | Latest | Background jobs |
| dry-monads | ~1.6 | Operation results |
| dry-validation | Latest | Form validation |
| RSpec | Latest | Testing |
| Docker | Latest | Development |
| Kamal | Latest | Deployment |

### Design Principles

1. **Thin Models** — ActiveRecord handles persistence, not business logic
2. **Thin Controllers** — Delegate to operations, handle HTTP only
3. **Operations for Logic** — All business logic in `app/components/*/operation/`
4. **Railway-Oriented** — Use dry-monads `Success`/`Failure` for control flow
5. **TDD** — Write tests first, all code must have specs
6. **Docker-First** — All development commands run in Docker

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           HTTP Request                               │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Controller                                   │
│  • Parse params                                                      │
│  • Call operation                                                    │
│  • Handle Success/Failure                                            │
│  • Render response                                                   │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Operation                                    │
│  • Validate input (Form/Contract)                                    │
│  • Execute business logic                                            │
│  • Coordinate models                                                 │
│  • Return Success(value) or Failure(error)                           │
└─────────────────────────────────────────────────────────────────────┘
                        │                    │
                        ▼                    ▼
┌──────────────────────────────┐  ┌──────────────────────────────────┐
│      Form/Contract           │  │            Model                  │
│  • Input validation          │  │  • Associations                   │
│  • Type coercion             │  │  • Validations                    │
│  • Schema definition         │  │  • Scopes                         │
└──────────────────────────────┘  │  • Persistence                    │
                                  └──────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Database                                     │
│  PostgreSQL                                                          │
└─────────────────────────────────────────────────────────────────────┘
```

### Async Processing

```
Operation ──▶ Job ──▶ Sidekiq Queue ──▶ Worker ──▶ Operation
     │                                                  │
     └──────────── (Background execution) ──────────────┘
```

---

## Directory Structure

```
kw-app/
├── app/
│   ├── components/                    # Business logic
│   │   ├── users/
│   │   │   ├── operation/
│   │   │   │   └── create.rb          # Users::Operation::Create
│   │   │   ├── contract/
│   │   │   │   └── create.rb          # Users::Contract::Create
│   │   │   └── create_form.rb         # Users::CreateForm (dry-validation)
│   │   ├── training/
│   │   │   └── supplementary/
│   │   │       └── operation/
│   │   │           └── create_course.rb
│   │   └── ...
│   │
│   ├── controllers/                   # HTTP handlers
│   │   ├── application_controller.rb
│   │   └── users_controller.rb
│   │
│   ├── models/
│   │   └── db/                        # ActiveRecord models (namespaced)
│   │       ├── user.rb                # Db::User
│   │       ├── profile.rb             # Db::Profile
│   │       └── ...
│   │
│   ├── jobs/                          # Background jobs
│   │   ├── application_job.rb
│   │   └── user_notification_job.rb
│   │
│   ├── mailers/                       # Email templates
│   └── views/                         # ERB templates
│
├── config/
│   ├── credentials/                   # Encrypted secrets
│   └── deploy.*.yml                   # Kamal deployment
│
├── db/
│   ├── migrate/                       # Migrations
│   └── schema.rb                      # Current schema
│
├── lib/
│   ├── playwright/                    # Browser automation helpers
│   └── ...
│
├── spec/                              # Tests (mirrors app/)
│   ├── components/
│   │   └── users/
│   │       └── operation/
│   │           └── create_spec.rb
│   ├── models/
│   │   └── db/
│   │       └── user_spec.rb
│   ├── requests/                      # Integration tests
│   ├── jobs/
│   └── factories/                     # FactoryBot factories
│
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md                # This file
│   ├── DEV_COMMANDS.md                # Shell commands
│   ├── FEATURE_WORKFLOW.md            # Feature development
│   └── KNOWN_ISSUES.md                # Known bugs
│
├── .agents/                           # AI agent specifications
│   ├── skills/                        # Deep knowledge modules
│   └── *.md                           # Individual agents
│
├── templates/                         # Code templates
│
├── .rules                             # AI constraints
├── AGENTS.md                          # Agent routing
├── CLAUDE.md                          # Quick reference
└── README.md                          # Human quickstart
```

---

## Layer Responsibilities

### Controllers (`app/controllers/`)

**Purpose:** Thin HTTP adapters. Parse requests, call operations, render responses.

**Rules:**
- ✅ Parse and permit params
- ✅ Call one operation per action
- ✅ Handle Success/Failure with pattern matching
- ✅ Set flash messages
- ✅ Redirect or render
- ❌ NO business logic
- ❌ NO direct model manipulation (except simple queries)
- ❌ NO email sending
- ❌ NO external API calls

**Example:**

```ruby
class UsersController < ApplicationController
  def create
    result = Users::Operation::Create.new.call(params: user_params)
    
    case result
    in Success(user)
      redirect_to user, notice: 'User created successfully'
    in Failure(errors)
      @errors = errors
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:email, :first_name, :last_name)
  end
end
```

### Operations (`app/components/*/operation/`)

**Purpose:** All business logic. Validation, coordination, side effects.

**Rules:**
- ✅ Include `Dry::Monads[:result, :do]`
- ✅ Return `Success(value)` or `Failure(error)`
- ✅ Use `yield` for chaining operations
- ✅ Call forms/contracts for validation
- ✅ Coordinate multiple models
- ✅ Queue background jobs
- ❌ NO HTTP concerns (params permitted in controller)
- ❌ NO rendering
- ❌ NO session/cookies

**Example:**

```ruby
class Users::Operation::Create
  include Dry::Monads[:result, :do]
  
  def call(params:)
    validated = yield validate!(params)
    user      = yield persist!(validated)
    _         = yield notify!(user)
    
    Success(user)
  end
  
  private
  
  def validate!(params)
    contract = Users::Contract::Create.new.call(params)
    contract.success? ? Success(contract.to_h) : Failure(contract.errors.to_h)
  end
  
  def persist!(attrs)
    user = Db::User.new(attrs)
    user.save ? Success(user) : Failure(user.errors.to_h)
  end
  
  def notify!(user)
    UserNotificationJob.perform_later(user.id)
    Success(user)
  end
end
```

### Forms/Contracts (`app/components/*/contract/` or `*_form.rb`)

**Purpose:** Input validation using dry-validation.

**Rules:**
- ✅ Extend `Dry::Validation::Contract`
- ✅ Define schema with types
- ✅ Add custom validation rules
- ✅ Use `option` for injected dependencies
- ❌ NO business logic
- ❌ NO persistence

**Example:**

```ruby
class Users::Contract::Create < Dry::Validation::Contract
  params do
    required(:user).hash do
      required(:email).filled(:string)
      required(:first_name).filled(:string)
      required(:last_name).filled(:string)
      optional(:phone).maybe(:string)
    end
  end
  
  rule(:user) do
    if values[:user][:email].present?
      unless values[:user][:email].match?(URI::MailTo::EMAIL_REGEXP)
        key(:user, :email).failure('is not a valid email')
      end
    end
  end
end
```

### Models (`app/models/db/`)

**Purpose:** Thin ActiveRecord. Associations, validations, scopes, persistence.

**Rules:**
- ✅ Define associations
- ✅ Define validations
- ✅ Define scopes
- ✅ Simple instance methods (predicates, formatters)
- ❌ NO complex business logic
- ❌ NO external API calls
- ❌ NO email sending
- ❌ NO callbacks with side effects (use sparingly)

**Example:**

```ruby
module Db
  class User < ApplicationRecord
    # Associations
    has_many :posts, dependent: :destroy
    has_one :profile, dependent: :destroy
    belongs_to :organization, optional: true
    
    # Validations
    validates :email, presence: true, uniqueness: { case_sensitive: false }
    validates :first_name, :last_name, presence: true
    
    # Scopes
    scope :active, -> { where(active: true) }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_organization, ->(org_id) { where(organization_id: org_id) }
    
    # Simple callbacks (data normalization only)
    before_validation :normalize_email
    
    # Simple methods
    def full_name
      "#{first_name} #{last_name}"
    end
    
    def active?
      active == true
    end
    
    private
    
    def normalize_email
      self.email = email.to_s.downcase.strip
    end
  end
end
```

### Jobs (`app/jobs/`)

**Purpose:** Background processing via Sidekiq.

**Rules:**
- ✅ Inherit from `ApplicationJob`
- ✅ Pass IDs, not objects
- ✅ Handle missing records gracefully
- ✅ Use retry/discard for error handling
- ✅ Call operations for business logic
- ❌ NO complex logic in jobs (delegate to operations)
- ❌ NO passing ActiveRecord objects

**Example:**

```ruby
class UserNotificationJob < ApplicationJob
  queue_as :default
  
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
  
  def perform(user_id, notification_type = :welcome)
    user = Db::User.find_by(id: user_id)
    return unless user
    
    case notification_type.to_sym
    when :welcome
      UserMailer.welcome(user).deliver_now
    when :reminder
      UserMailer.reminder(user).deliver_now
    end
  end
end
```

---

## Code Patterns

### dry-monads Railway Pattern

```ruby
class Orders::Operation::Create
  include Dry::Monads[:result, :do]
  
  def call(user:, params:)
    validated = yield validate!(params)       # Stop if validation fails
    cart      = yield fetch_cart!(user)       # Stop if cart not found
    order     = yield create_order!(user, validated, cart)
    _         = yield process_payment!(order) # Stop if payment fails
    _         = yield send_confirmation!(order)
    _         = yield clear_cart!(cart)
    
    Success(order)
  end
  
  private
  
  def validate!(params)
    # Returns Success(data) or Failure(errors)
  end
  
  def fetch_cart!(user)
    cart = user.cart
    cart.present? ? Success(cart) : Failure(cart: ['not found'])
  end
  
  # ... other methods return Success/Failure
end
```

### Controller Pattern Matching

```ruby
def create
  result = MyOperation.new.call(params: params)
  
  case result
  in Success(data)
    redirect_to data, notice: 'Created!'
  in Failure([:not_found, message])
    redirect_to root_path, alert: message
  in Failure([:unauthorized, _])
    redirect_to root_path, alert: 'Not authorized'
  in Failure(errors) if errors.is_a?(Hash)
    @errors = errors
    render :new, status: :unprocessable_entity
  end
end
```

### Validation Contract with Options

```ruby
class Settlement::ContractForm < Dry::Validation::Contract
  option :record, default: -> { nil }
  
  params do
    required(:cost).filled(:decimal)
    required(:description).filled(:string)
  end
  
  rule(:cost) do
    if record && values[:cost] < record.minimum_cost
      key.failure("must be at least #{record.minimum_cost}")
    end
  end
end

# Usage in operation:
form = Settlement::ContractForm.new(record: existing_record)
result = form.call(params)
```

---

## Dependency Injection

### Container Registration

```ruby
# config/initializers/container.rb
class AppContainer
  extend Dry::Container::Mixin
  
  register 'repos.user' do
    UserRepo.new
  end
  
  register 'operations.users.create' do
    Users::Operation::Create.new
  end
end
```

### Auto-Injection

```ruby
class UsersController < ApplicationController
  include AutoInject['operations.users.create']
  
  def create
    result = operations_users_create.call(params: user_params)
    # ...
  end
end
```

---

## Naming Conventions

### Files and Classes

| Component | Class Name | File Path |
|-----------|------------|-----------|
| Model | `Db::User` | `app/models/db/user.rb` |
| Operation | `Users::Operation::Create` | `app/components/users/operation/create.rb` |
| Contract | `Users::Contract::Create` | `app/components/users/contract/create.rb` |
| Form | `Users::CreateForm` | `app/components/users/create_form.rb` |
| Job | `UserNotificationJob` | `app/jobs/user_notification_job.rb` |
| Controller | `UsersController` | `app/controllers/users_controller.rb` |
| Spec | `RSpec.describe Users::Operation::Create` | `spec/components/users/operation/create_spec.rb` |
| Factory | `factory :user` | `spec/factories/users.rb` |

### Operation Naming

| Action | Pattern | Example |
|--------|---------|---------|
| Create | `Namespace::Operation::Create` | `Users::Operation::Create` |
| Update | `Namespace::Operation::Update` | `Users::Operation::Update` |
| Delete | `Namespace::Operation::Delete` | `Users::Operation::Delete` |
| Custom | `Namespace::Operation::ActionName` | `Users::Operation::VerifyEmail` |

---

## Data Flow Examples

### Create User Flow

```
1. HTTP POST /users
       │
2. UsersController#create
   └── params = { user: { email: '...', first_name: '...' } }
       │
3. Users::Operation::Create.call(params: params)
       │
4. ├── validate!(params)
   │   └── Users::Contract::Create.call(params)
   │       └── Returns Success({ email: '...', first_name: '...' })
       │
5. ├── persist!(validated)
   │   └── Db::User.create(validated)
   │       └── Returns Success(#<Db::User id: 1>)
       │
6. └── notify!(user)
       └── UserNotificationJob.perform_later(user.id)
           └── Returns Success(user)
       │
7. Returns Success(user) to controller
       │
8. Controller: redirect_to user, notice: 'Created!'
```

---

## Testing Architecture

### Spec Structure

```
spec/
├── components/           # Operation/Service specs
│   └── users/
│       └── operation/
│           └── create_spec.rb
├── models/               # Model specs
│   └── db/
│       └── user_spec.rb
├── requests/             # Integration/Request specs
│   └── users_spec.rb
├── jobs/                 # Job specs
│   └── user_notification_job_spec.rb
├── factories/            # FactoryBot factories
│   └── users.rb
├── support/              # Test helpers
│   ├── factory_bot.rb
│   └── dry_monads.rb
└── rails_helper.rb
```

### Operation Spec Pattern

```ruby
RSpec.describe Users::Operation::Create do
  subject(:operation) { described_class.new }
  
  describe '#call' do
    let(:valid_params) do
      { user: { email: 'test@example.com', first_name: 'John', last_name: 'Doe' } }
    end
    
    context 'with valid params' do
      it 'returns Success with user' do
        result = operation.call(params: valid_params)
        
        expect(result).to be_success
        expect(result.success).to be_a(Db::User)
        expect(result.success.email).to eq('test@example.com')
      end
      
      it 'creates a user' do
        expect { operation.call(params: valid_params) }
          .to change(Db::User, :count).by(1)
      end
      
      it 'enqueues notification job' do
        expect { operation.call(params: valid_params) }
          .to have_enqueued_job(UserNotificationJob)
      end
    end
    
    context 'with invalid params' do
      let(:invalid_params) { { user: { email: '' } } }
      
      it 'returns Failure with errors' do
        result = operation.call(params: invalid_params)
        
        expect(result).to be_failure
        expect(result.failure).to include(:email)
      end
      
      it 'does not create a user' do
        expect { operation.call(params: invalid_params) }
          .not_to change(Db::User, :count)
      end
    end
  end
end
```

### Request Spec Pattern

```ruby
RSpec.describe 'Users', type: :request do
  describe 'POST /users' do
    let(:valid_params) do
      { user: { email: 'test@example.com', first_name: 'John', last_name: 'Doe' } }
    end
    
    context 'with valid params' do
      it 'creates user and redirects' do
        post users_path, params: valid_params
        
        expect(response).to redirect_to(user_path(Db::User.last))
        expect(flash[:notice]).to eq('User created successfully')
      end
    end
    
    context 'with invalid params' do
      it 'renders form with errors' do
        post users_path, params: { user: { email: '' } }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('error')
      end
    end
  end
end
```

---

## Background Jobs

### When to Use Jobs

| Use Job When | Don't Use Job When |
|--------------|-------------------|
| Operation takes >500ms | Quick database update |
| External API call | Simple validation |
| Email sending | Immediate response needed |
| File processing | User expects instant feedback |
| Batch operations | |

### Job Pattern

```ruby
# In operation - enqueue job
def notify!(user)
  UserNotificationJob.perform_later(user.id)
  Success(user)
end

# In job - delegate to operation or simple logic
class UserNotificationJob < ApplicationJob
  def perform(user_id)
    user = Db::User.find_by(id: user_id)
    return unless user
    
    UserMailer.welcome(user).deliver_now
  end
end
```

---

## Migration Patterns

### From Custom Result to dry-monads

See `docs/KNOWN_ISSUES.md` for the full migration guide.

**Before (DEPRECATED):**
```ruby
require 'result'

class SomeService
  def call
    return Failure(:invalid, errors: {}) unless valid?
    Success(:success)
  end
end
```

**After (CURRENT):**
```ruby
class SomeOperation
  include Dry::Monads[:result, :do]
  
  def call
    return Failure({}) unless valid?
    Success(:done)
  end
end
```

---

## Related Documentation

- **[.rules](../.rules)** - AI constraints
- **[DEV_COMMANDS.md](DEV_COMMANDS.md)** - Shell commands
- **[FEATURE_WORKFLOW.md](FEATURE_WORKFLOW.md)** - Feature development
- **[KNOWN_ISSUES.md](KNOWN_ISSUES.md)** - Known bugs and solutions
- **[.agents/skills/dry-monads-patterns/SKILL.md](../.agents/skills/dry-monads-patterns/SKILL.md)** - dry-monads deep dive

---

**Version:** 1.0  
**Last Updated:** 2025
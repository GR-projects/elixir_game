# Business Logic Tests

This directory contains comprehensive tests for the `BusinessLogic` module, covering all business logic functions including user management, character management, authentication, and ETS caching behavior.

## Test Structure

- **`business_logic_test.exs`** - Main test file covering all business logic functions
- **`ets_caching_test.exs`** - Tests specifically for ETS caching behavior
- **`authentication_test.exs`** - Tests for authentication and security aspects
- **`character_management_test.exs`** - Tests for character creation, retrieval, and deletion
- **`support/business_logic_test_helpers.ex`** - Helper functions for test data generation and mocking

## Running Tests

To run all tests:
```bash
cd apps/business_logic
mix test
```

To run a specific test file:
```bash
mix test test/business_logic_test.exs
mix test test/ets_caching_test.exs
mix test test/authentication_test.exs
mix test test/character_management_test.exs
```

To run tests with coverage:
```bash
mix test --cover
```

## Test Dependencies

The tests use the following libraries:
- **ExUnit** - Elixir's built-in testing framework
- **Mock** - For mocking external dependencies (Data module, Utils.ETS, Data.Repo)
- **Faker** - For generating realistic test data

## Test Data

The `BusinessLogic.TestHelpers` module provides functions to create consistent test data:
- `create_test_user/1` - Creates test users with realistic data
- `create_test_character/1` - Creates test characters with configurable attributes
- `create_test_item/1` - Creates test items for characters

## Mocking Strategy

Tests use the `Mock` library to isolate the `BusinessLogic` module from its dependencies:

- **Data module** - Mocked to avoid database calls during testing
- **Utils.ETS** - Mocked to test caching behavior without actual ETS tables
- **Data.Repo** - Mocked for preload operations

This approach allows for fast, focused unit tests that don't require a running database or external services.

## Test Coverage

The tests cover:

### User Management
- User creation with password hashing
- User authentication (success and failure cases)
- Input validation and edge cases

### Character Management
- Character creation with default values
- Character retrieval by ID
- Character deletion
- Parameter handling and validation

### ETS Caching
- Cache hit/miss behavior
- Cache invalidation
- Separate caching for different users

### Authentication & Security
- Password hashing with bcrypt
- Password verification
- Security edge cases
- Input validation

### Edge Cases
- Nil/empty parameter handling
- Error conditions
- Malformed input handling

## Adding New Tests

When adding new business logic functions:

1. Add tests to the appropriate test file or create a new one
2. Use the helper functions for consistent test data
3. Mock external dependencies appropriately
4. Test both success and failure scenarios
5. Include edge cases and error handling

## Configuration

Test configuration is in `config/test.exs` and includes:
- Database configuration for testing
- Logger level settings
- Phoenix endpoint configuration for testing

## Best Practices

- Each test should be independent and not rely on other tests
- Use descriptive test names that explain the expected behavior
- Mock external dependencies to ensure fast, reliable tests
- Test both happy path and error scenarios
- Use helper functions for consistent test data generation 
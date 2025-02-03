# Testing
- We should test early and often, and Tests should be updated with everything we do
- If a component is updated, associated tests should be updated
# Environments
- Development and Production environments should be kept separate by using our environment variables.
- Changes should be easy to deploy as soon as they are tested in the Development Environment
- We will have one local Supabase Instance
- Environment Variables that are different between environments should have the _DEV and _PROD prefix
# Database and API
- We want to create our Database and API first, and we want it to be as easy to use as possible.
- All CRUD Operations should be done within our API
- All Supabase entities should be RealTime enabled by Default
- API Operations should be handled immediately
- Keys are necessary for API
- Schemas should be flexible; it should be easy to add new fields and relationships
- Migrations should not be overcomplicated; they should be kept simple
- Changes to the Database should be meticulously documented
- Changes to the API should be meticulously documented
- Please keep in mind that we will need seed data in order to test all of our features.
# UI
- Everything we do should be optimized for Mobile as well
- Verify before changing anything elated to UI/UX, unless it is specifically requested in the prompt.
# AI
- AI Operations will be done with an Edge function, either in Supabase or AWS Cloud Functions, depending on the use case
# Performance
- Event-driven architecture should be supported
- Prioritize Caching to reduce load for frequently accessed data
- Improve System Efficiency through Query Optimization where possible
- Handle Attachments and Large Datasets gracefully
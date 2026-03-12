-- Database Schema for NeztMate Property Management App
-- This schema is designed for a relational database like PostgreSQL.
-- It covers core entities: Users (with roles), Properties, Units, Leases, Maintenance, Tasks, Payments, Messages, Community, Invites, and related features.
-- Assumptions:
-- - Uses UUID for primary keys where appropriate for scalability.
-- - Timestamps for created/updated.
-- - Role-based access: Users have a 'role' enum (Tenant, Landowner, Manager, Artisan).
-- - Relationships: Foreign keys (FK) enforce integrity.
-- - Indexes suggested for frequent queries (e.g., by user, property).
-- - Currency in NGN (Naira) for Nigeria focus, but adaptable.
-- - Security: Passwords hashed, sensitive data (e.g., income) encrypted if needed.

-- Enum Types
CREATE TYPE user_role AS ENUM ('Tenant', 'Landowner', 'Manager', 'Artisan');
CREATE TYPE priority_level AS ENUM ('Low', 'Medium', 'High', 'Emergency');
CREATE TYPE payment_status AS ENUM ('Pending', 'Paid', 'Overdue', 'Refunded');
CREATE TYPE task_status AS ENUM ('Pending', 'Assigned', 'InProgress', 'Completed', 'Approved', 'Rejected');
CREATE TYPE property_type AS ENUM ('Apartment', 'House', 'Commercial');
CREATE TYPE amenity_type AS ENUM ('WiFi', 'Parking', 'Pool', 'Gym', 'Balcony', 'Furnished', 'PetFriendly', 'AirConditioning'); -- Expand as needed

-- Users Table (Central for all roles)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50) UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- Hashed
    full_name VARCHAR(255) NOT NULL,
    profile_photo_url TEXT,
    role user_role NOT NULL,
    verified_identity BOOLEAN DEFAULT FALSE,
    verified_employment BOOLEAN DEFAULT FALSE,
    years_experience INTEGER, -- For Artisans/Managers
    primary_skill VARCHAR(100), -- For Artisans (e.g., 'Plumber')
    rating DECIMAL(3,2) DEFAULT 0.0,
    response_time INTERVAL, -- e.g., '30 minutes'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Properties Table (Buildings/Complexes owned by Landowners)
CREATE TABLE properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL, -- e.g., 'Sunset Heights Apartment'
    type property_type NOT NULL,
    address TEXT NOT NULL,
    landowner_id UUID REFERENCES users(id) ON DELETE CASCADE, -- FK to Users (Landowner role)
    manager_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Optional FK to Manager
    photo_urls TEXT[], -- Array of URLs
    amenities amenity_type[], -- Array of enums
    total_units INTEGER DEFAULT 0,
    occupancy_rate DECIMAL(5,2) DEFAULT 0.0, -- Computed or updated via trigger
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_properties_landowner ON properties(landowner_id);
CREATE INDEX idx_properties_manager ON properties(manager_id);

-- Units Table (Individual apartments/rooms within Properties)
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    unit_number VARCHAR(50) NOT NULL, -- e.g., 'Apt 4B'
    floor_level INTEGER,
    monthly_rent DECIMAL(10,2) NOT NULL,
    bedrooms INTEGER,
    bathrooms DECIMAL(3,1), -- e.g., 1.5
    likes INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    square_feet INTEGER,
    features amenity_type[], -- Subset of property amenities + unit-specific
    photo_urls TEXT[],
    video_urls VARCHAR NOT NULL,
    status ENUM('Occupied', 'Vacant', 'Repair') NOT NULL DEFAULT 'Vacant',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Comments on Units
CREATE TABLE post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_units_property ON units(property_id);

-- Leases Table (Agreements between Tenants and Landowners)
CREATE TABLE leases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES users(id) ON DELETE CASCADE, -- FK to Tenant user
    landowner_id UUID REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    monthly_rent DECIMAL(10,2) NOT NULL,
    security_deposit DECIMAL(10,2),
    signed_pdf_url TEXT, -- Stored signed document
    status ENUM('Active', 'Expired', 'Terminated') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_leases_unit ON leases(unit_id);
CREATE INDEX idx_leases_tenant ON leases(tenant_id);

-- Maintenance Requests Table (Reported issues by Tenants)
CREATE TABLE maintenance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES users(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    priority priority_level NOT NULL,
    photo_urls TEXT[], -- Evidence from tenant
    status task_status DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_maintenance_unit ON maintenance_requests(unit_id);
CREATE INDEX idx_maintenance_tenant ON maintenance_requests(tenant_id);

-- Tasks Table (Assigned maintenance to Artisans)
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    artisan_id UUID REFERENCES users(id) ON DELETE SET NULL, -- FK to Artisan
    manager_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Assigner
    description TEXT,
    before_photos TEXT[],
    after_photos TEXT[],
    work_summary TEXT,
    total_cost DECIMAL(10,2),
    status task_status DEFAULT 'Assigned',
    scheduled_time TIMESTAMP,
    completed_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_tasks_request ON tasks(request_id);
CREATE INDEX idx_tasks_artisan ON tasks(artisan_id);

-- Payments Table (Rent, Deposits, Artisan Fees)
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_id UUID REFERENCES leases(id) ON DELETE SET NULL, -- For rent
    task_id UUID REFERENCES tasks(id) ON DELETE SET NULL, -- For repairs
    payer_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Tenant or Landowner
    amount DECIMAL(10,2) NOT NULL,
    currency CHAR(3) DEFAULT 'NGN', -- Naira
    status payment_status NOT NULL,
    method VARCHAR(50), -- e.g., 'Bank', 'Paystack'
    receipt_pdf_url TEXT,
    due_date DATE,
    paid_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_payments_lease ON payments(lease_id);
CREATE INDEX idx_payments_task ON payments(task_id);

-- Messages Table (In-app chat between roles)
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    attachment_urls TEXT[], -- Photos, PDFs
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_property ON messages(property_id);

-- Community Posts Table (Announcements, Events in Feed)
CREATE TABLE community_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Manager or Landowner
    title VARCHAR(255),
    content TEXT NOT NULL,
    type ENUM('Announcement', 'Event', 'Alert'),
    photo_urls TEXT[],
    likes INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    event_time TIMESTAMP, -- For events
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_community_property ON community_posts(property_id);

-- Comments on Community Posts
CREATE TABLE post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invites Table (For team members: Managers, Artisans)
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Landowner/Manager
    invitee_email VARCHAR(255) NOT NULL,
    invitee_phone VARCHAR(50),
    role user_role NOT NULL,
    property_ids UUID[], -- Array of assigned properties
    message TEXT,
    status ENUM('Pending', 'Accepted', 'Declined') DEFAULT 'Pending',
    invite_link TEXT UNIQUE, -- Generated link
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);
CREATE INDEX idx_invites_inviter ON invites(inviter_id);

-- Certifications/Licenses Table (For Artisans)
CREATE TABLE certifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artisan_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    document_url TEXT,
    issued_date DATE,
    expiry_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Availability Table (For Artisans' Schedules)
CREATE TABLE availabilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artisan_id UUID REFERENCES users(id) ON DELETE CASCADE,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    recurring BOOLEAN DEFAULT FALSE, -- Weekly/monthly
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_availabilities_artisan ON availabilities(artisan_id);

-- Additional Notes:
-- Triggers: e.g., Update property occupancy_rate on unit status change.
-- Views: For analytics (e.g., revenue trends via GROUP BY month).
-- Security: Row-Level Security (RLS) in Postgres to enforce role-based access (e.g., Tenants see only their data).
-- Scalability: Partition large tables like messages/payments by date.
-- Integrations: External IDs for payments (e.g., Paystack txn_id).
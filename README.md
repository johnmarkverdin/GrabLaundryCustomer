👤 README — CUSTOMER APP
📌 Overview

The Customer App allows customers to book laundry pickup, view booking status, assigned rider, and billing.
Updates live through Supabase Realtime.

✨ Customer Features
🧾 Create Laundry Order

Customer fills:

Name

Pickup location

Service type (type or choose)

Payment method

Pickup & delivery datetime

Notes (optional)

💬 Realtime Order Updates

Whenever:

rider updates status

admin assigns rider

admin updates total price

The customer sees it instantly in their dashboard.

👀 View My Orders

Each order shows:

order ID

status

service

addresses

payment method

schedule

notes

total price (added by admin)

assigned rider info:

rider name

rider phone

rider ID

🔄 Refresh Button

Reload button in top-right

Pull-to-refresh also available

🚪 Logout

Customer logs out easily.

🗄 Database Tables Used
profiles

Customer has:

role = 'customer'

laundry_orders

Customer sees:

only their own orders

rider info through joined profiles

real-time updates

🔐 Supabase RLS Policies (Customer)
create policy "customer_select_own"
on laundry_orders
for select
using (auth.uid() = customer_id);

create policy "customer_insert_own"
on laundry_orders
for insert
with check (auth.uid() = customer_id);


Customers cannot:

delete

change rider

change status

Only admin or rider can.

▶️ How to Run Customer App
1. Get packages
   flutter pub get

2. Configure Supabase

Inside supabase_config.dart:

await Supabase.initialize(
url: "https://<YOUR-PROJECT>.supabase.co",
anonKey: "<YOUR-ANON-KEY>",
);

3. Run customer app
   flutter run


Customer dashboard loads automatically.
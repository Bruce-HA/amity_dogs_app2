from supabase import create_client
import os

SUPABASE_URL = https://phkwizyrpfzoecugpshb.supabase.co
SUPABASE_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBoa3dpenlycGZ6b2VjdWdwc2hiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTM2NjI4MiwiZXhwIjoyMDg0OTQyMjgyfQ.XF9Mi_Pzp-F2AQflrFEbuftf1rqavZWsLUwRoS6XpHA

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

bucket = "dog_files"

# get dogs
dogs = supabase.table("dogs").select("id,dog_ala").execute().data

for dog in dogs:

    dog_id = dog["id"]
    dog_ala = dog["dog_ala"]

    print(f"Migrating {dog_id} → {dog_ala}")

    # list files
    files = supabase.storage.from_(bucket).list(dog_id)

    for folder in files:

        folder_name = folder["name"]

        subfiles = supabase.storage.from_(bucket).list(f"{dog_id}/{folder_name}")

        for file in subfiles:

            filename = file["name"]

            old_path = f"{dog_id}/{folder_name}/{filename}"

            if folder_name == "photo":
                new_folder = "photos"
            else:
                new_folder = folder_name

            new_path = f"{dog_ala}/{new_folder}/{filename}"

            print(f"Moving {old_path} → {new_path}")

            supabase.storage.from_(bucket).move(old_path, new_path)

print("Migration complete")
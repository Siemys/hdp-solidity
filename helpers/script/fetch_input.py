
class InputFetcher:
     def prompt_for_fixture(self):
            # get collection type from user
            collection_type = input("Enter the collection type: ")
            # get collection property type from user
            collection_property_type = input("Enter the collection property type: ")
            # get input.json file from path hdp-test/{collection_type}/collection_property_type/input.json
            selected_fixture_path = f"hdp-test/{collection_type}/{collection_property_type}/input.json"
            # move file to helpers/target/cached_input.json

          
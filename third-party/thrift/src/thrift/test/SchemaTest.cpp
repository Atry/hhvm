/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <folly/portability/GTest.h>
#include <thrift/lib/thrift/gen-cpp2/schema_types.h>
#include <thrift/test/gen-cpp2/schema_constants.h>

using namespace facebook::thrift::test::schema;

TEST(SchemaTest, Empty) {
  auto schema = schema_constants::schemaEmpty();
  EXPECT_EQ(*schema.name(), "Empty");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/Empty");
  EXPECT_TRUE(schema.fields()->empty());
}

TEST(SchemaTest, Renamed) {
  auto schema = schema_constants::RenamedSchema();
  EXPECT_EQ(*schema.name(), "Renamed");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/Renamed");
  EXPECT_TRUE(schema.fields()->empty());
}

TEST(SchemaTest, Fields) {
  facebook::thrift::type::Struct schema = schema_constants::schemaFields();
  EXPECT_EQ(schema.fields()->size(), 3);

  // 1: i32 num;
  auto field = schema.fields()->at(0);
  EXPECT_EQ(*field.name(), "num");
  EXPECT_EQ(*field.id(), apache::thrift::type::FieldId{1});
  EXPECT_EQ(*field.qualifier(), facebook::thrift::type::FieldQualifier::Fill);
  EXPECT_EQ(
      field.type()->toThrift().name()->getType(),
      apache::thrift::type::TypeName::Type::i32Type);

  // 3: optional set<string> keyset;
  field = schema.fields()->at(1);
  EXPECT_EQ(*field.name(), "keyset");
  EXPECT_EQ(*field.id(), apache::thrift::type::FieldId{3});
  EXPECT_EQ(
      *field.qualifier(), facebook::thrift::type::FieldQualifier::Optional);
  EXPECT_EQ(
      field.type()->toThrift().name()->getType(),
      apache::thrift::type::TypeName::Type::setType);
  EXPECT_EQ(field.type()->toThrift().params()->size(), 1);
  EXPECT_EQ(
      field.type()->toThrift().params()->at(0).name()->getType(),
      apache::thrift::type::TypeName::Type::stringType);

  // 7: Empty strct;
  field = schema.fields()->at(2);
  EXPECT_EQ(*field.name(), "strct");
  EXPECT_EQ(*field.id(), apache::thrift::type::FieldId{7});
  EXPECT_EQ(*field.qualifier(), facebook::thrift::type::FieldQualifier::Fill);
  EXPECT_EQ(
      field.type()->toThrift().name()->getType(),
      apache::thrift::type::TypeName::Type::structType);
  EXPECT_EQ(
      *field.type()->toThrift().name()->structType_ref()->uri_ref(),
      "facebook.com/thrift/test/schema/Empty");
}

TEST(SchemaTest, Defaults) {
  EXPECT_THROW(
      schema_constants::getValue(apache::thrift::type::ValueId{}),
      std::out_of_range);
  EXPECT_THROW(
      schema_constants::getValue(apache::thrift::type::ValueId{42}),
      std::out_of_range);

  auto schema = schema_constants::schemaDefaults();
  EXPECT_EQ(schema.fields()->size(), 2);

  // 1: i32 none;
  auto field = schema.fields()->at(0);
  EXPECT_EQ(*field.name(), "none");
  EXPECT_EQ(*field.customDefault(), apache::thrift::type::ValueId{});

  // 2: i32 some = 42;
  field = schema.fields()->at(1);
  EXPECT_EQ(*field.name(), "some");
  EXPECT_EQ(
      schema_constants::getValue(*field.customDefault())
          .as<apache::thrift::type::i32_t>(),
      42);
}

TEST(SchemaTest, Union) {
  facebook::thrift::type::Union schema = schema_constants::schemaUnion();
  EXPECT_EQ(*schema.name(), "Union");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/Union");
  EXPECT_TRUE(schema.fields()->empty());
}

TEST(SchemaTest, Exception) {
  facebook::thrift::type::Exception schema =
      schema_constants::schemaSimpleException();
  EXPECT_EQ(*schema.name(), "SimpleException");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/SimpleException");
  EXPECT_TRUE(schema.fields()->empty());
  EXPECT_EQ(*schema.safety(), facebook::thrift::type::ErrorSafety::Unspecified);
  EXPECT_EQ(*schema.kind(), facebook::thrift::type::ErrorKind::Unspecified);
  EXPECT_EQ(*schema.blame(), facebook::thrift::type::ErrorBlame::Unspecified);

  schema = schema_constants::schemaFancyException();
  EXPECT_EQ(*schema.safety(), facebook::thrift::type::ErrorSafety::Safe);
  EXPECT_EQ(*schema.kind(), facebook::thrift::type::ErrorKind::Transient);
  EXPECT_EQ(*schema.blame(), facebook::thrift::type::ErrorBlame::Server);
}

TEST(SchemaTest, EmptyService) {
  auto schema = schema_constants::schemaEmptyService();
  EXPECT_EQ(*schema.name(), "EmptyService");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/EmptyService");
  EXPECT_TRUE(schema.functions()->empty());
}

TEST(SchemaTest, IntConst) {
  facebook::thrift::type::Const schema = schema_constants::schemaIntConst();
  EXPECT_EQ(*schema.name(), "IntConst");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/IntConst");
  EXPECT_EQ(
      schema.type()->toThrift().name()->getType(),
      apache::thrift::type::TypeName::Type::i32Type);
  EXPECT_EQ(
      schema_constants::getValue(*schema.value())
          .as<apache::thrift::type::i32_t>(),
      11);
}

TEST(SchemaTest, ListConst) {
  facebook::thrift::type::Const schema = schema_constants::schemaListConst();
  EXPECT_EQ(*schema.name(), "ListConst");
  EXPECT_EQ(*schema.uri(), "facebook.com/thrift/test/schema/ListConst");
  EXPECT_EQ(
      schema.type()->toThrift().name()->getType(),
      apache::thrift::type::TypeName::Type::listType);
  EXPECT_EQ(schema.type()->toThrift().params()->size(), 1);
  EXPECT_EQ(
      schema.type()->toThrift().params()->at(0).name()->getType(),
      apache::thrift::type::TypeName::Type::i32Type);

  auto list_values =
      schema_constants::getValue(*schema.value())
          .as<apache::thrift::type::list<apache::thrift::type::i32_t>>();
  EXPECT_EQ(list_values.size(), 5);
  EXPECT_EQ(list_values[0], 2);
  EXPECT_EQ(list_values[1], 3);
  EXPECT_EQ(list_values[2], 5);
  EXPECT_EQ(list_values[3], 7);
  EXPECT_EQ(list_values[4], 11);
}

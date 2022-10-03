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
#include <thrift/lib/cpp2/BoxedValuePtr.h>

using namespace apache::thrift::detail;

struct TestStruct {
  TestStruct() : a(0) {}
  TestStruct(int val) : a(val) {}
  TestStruct(const TestStruct& other) : a(other.a) {}

  TestStruct& operator=(const TestStruct& other) {
    TestStruct tmp{other};
    std::swap(a, tmp.a);
    return *this;
  }

  TestStruct& operator=(int val) {
    TestStruct tmp{val};
    std::swap(a, tmp.a);
    return *this;
  }

  int a;
};

constexpr bool operator==(const TestStruct& lhs, int rhs) {
  return lhs.a == rhs;
}

constexpr bool operator==(int lhs, const TestStruct& rhs) {
  return lhs == rhs.a;
}

template <typename T>
class BoxedTest : public ::testing::Test {};

using BoxedPtrTypes =
    ::testing::Types<boxed_value_ptr<TestStruct>, boxed_ptr<TestStruct>>;

TYPED_TEST_SUITE(BoxedTest, BoxedPtrTypes);

TYPED_TEST(BoxedTest, DefaultConstructor) {
  TypeParam a;
  EXPECT_FALSE(static_cast<bool>(a));
}

TYPED_TEST(BoxedTest, Constructor) {
  TypeParam a(5);
  EXPECT_EQ(*a, 5);
}

TYPED_TEST(BoxedTest, CopyConstructor) {
  TypeParam a(5);
  TypeParam b(a);
  EXPECT_EQ(*b, 5);
  EXPECT_EQ(*a, 5);
}

TYPED_TEST(BoxedTest, CopyAssignment) {
  TypeParam a(5);
  TypeParam b;
  b = a;
  EXPECT_EQ(*b, 5);
  EXPECT_EQ(*a, 5);
}

TYPED_TEST(BoxedTest, MoveConstructor) {
  TypeParam a(5);
  TypeParam b(std::move(a));
  EXPECT_EQ(*b, 5);
}

TYPED_TEST(BoxedTest, MoveAssignment) {
  TypeParam a(5);
  TypeParam b;
  b = std::move(a);
  EXPECT_EQ(*b, 5);
}

TYPED_TEST(BoxedTest, EmptyAssignment) {
  TypeParam a;
  TypeParam b(5);
  EXPECT_EQ(*b, 5);
  b = a;
  EXPECT_FALSE(static_cast<bool>(b));
}

TYPED_TEST(BoxedTest, Emplace) {
  TypeParam a;
  a.emplace(5);
  EXPECT_EQ(*a, 5);
  a.emplace(7);
  EXPECT_EQ(*a, 7);
}

TYPED_TEST(BoxedTest, Reset) {
  TypeParam a(6);
  a.reset();
  EXPECT_FALSE(static_cast<bool>(a));
}

TYPED_TEST(BoxedTest, Assignment) {
  TypeParam a;
  a = 6;
  EXPECT_EQ(*a, 6);
}

TYPED_TEST(BoxedTest, MoveOnlyType) {
  boxed_value_ptr<std::unique_ptr<int>> a;
  a = std::make_unique<int>(5);
  EXPECT_EQ(**a, 5);
  boxed_value_ptr<std::unique_ptr<int>> b(std::move(a));
  EXPECT_EQ(**b, 5);
}

TYPED_TEST(BoxedTest, Swap) {
  TypeParam a(5);
  TypeParam b(7);
  std::swap(a, b);
  EXPECT_EQ(*a, 7);
  EXPECT_EQ(*b, 5);
}

TYPED_TEST(BoxedTest, Equal) {
  TypeParam a;
  TypeParam b;
  EXPECT_TRUE(a == b);
  a = 5;
  EXPECT_FALSE(a == b);
  b = 5;
  EXPECT_FALSE(a == b);
  b = 7;
  EXPECT_FALSE(a == b);
}

class LifecycleTester {
 public:
  using __fbthrift_cpp2_type = std::true_type;

  LifecycleTester() : isACopy_(false), hasBeenCopied_(false) {}
  explicit LifecycleTester(int) : isACopy_(false), hasBeenCopied_(false) {}

  // NOLINTNEXTLINE(facebook-hte-NonConstCopyContructor)
  LifecycleTester(LifecycleTester& other)
      : isACopy_(true), hasBeenCopied_(false) {
    other.hasBeenCopied_ = true;
  }

  LifecycleTester& operator=(LifecycleTester& other) {
    LifecycleTester tmp{other};
    std::swap(isACopy_, tmp.isACopy_);
    std::swap(hasBeenCopied_, tmp.hasBeenCopied_);
    other.hasBeenCopied_ = true;
    return *this;
  }

  bool isACopy() const { return isACopy_; }

  bool hasBeenCopied() const { return hasBeenCopied_; }

 private:
  bool isACopy_;
  bool hasBeenCopied_;
};

TEST(LifecycleTest, ConstUnownedCopy) {
  LifecycleTester lct;

  boxed_ptr<LifecycleTester> boxed1 = &lct;
  EXPECT_FALSE(boxed1->isACopy());
  EXPECT_FALSE(boxed1->hasBeenCopied());

  boxed_ptr<LifecycleTester> boxed2 = boxed1;
  EXPECT_FALSE(boxed1->hasBeenCopied());
  EXPECT_FALSE(boxed2->isACopy());

  EXPECT_FALSE(lct.hasBeenCopied());
  EXPECT_EQ(boxed1, boxed2);
}

TEST(LifecycleTest, MutOwnedRefCopy) {
  LifecycleTester lct;

  boxed_ptr<LifecycleTester> boxed{&lct};
  EXPECT_FALSE(boxed->isACopy());
  EXPECT_TRUE(boxed.mut()->isACopy()); // This mutable ref creates a copy.
  EXPECT_TRUE(lct.hasBeenCopied());
}

TEST(LifecycleTest, copyOfMutableRefCreatesCopy) {
  // Creating the object this way starts with a MutOwned state.
  boxed_ptr<LifecycleTester> boxed1{0};
  EXPECT_FALSE(boxed1->hasBeenCopied());
  auto boxed2 = boxed1;
  EXPECT_TRUE(boxed1->hasBeenCopied());
}

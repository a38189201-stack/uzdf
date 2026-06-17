-- AlterTable Order
ALTER TABLE "Order" ADD COLUMN "deliveryAddress" TEXT;
ALTER TABLE "Order" ADD COLUMN "deliveryCity" TEXT;
ALTER TABLE "Order" ADD COLUMN "deliveryContact" TEXT;

-- AlterTable User
ALTER TABLE "User" ADD COLUMN "dob" TEXT;
ALTER TABLE "User" ADD COLUMN "country" TEXT;

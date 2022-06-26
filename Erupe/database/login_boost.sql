ALTER TABLE "login_boost_state" ADD COLUMN "last_week" INTEGER;

UPDATE public.login_boost_state SET last_week=0;
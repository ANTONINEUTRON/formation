import { redirect } from "next/navigation";

const WAITLIST_FORM_URL = "https://forms.gle/eZYFLTdifqEfZd7aA";

export default function WaitlistPage() {
  redirect(WAITLIST_FORM_URL);
}

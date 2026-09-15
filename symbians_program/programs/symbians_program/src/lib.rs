use anchor_lang::prelude::*;

declare_id!("48KQQ5frwFYq2ukhcsocMEbqXzqHLM6QdQYVtzn5VfXF");

#[program]
pub mod symbians_program {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}

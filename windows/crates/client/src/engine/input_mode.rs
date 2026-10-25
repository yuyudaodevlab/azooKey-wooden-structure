use super::state::IMEState;
use crate::tsf::factory::TextServiceFactory;

use windows::{
    core::Interface,
    Win32::UI::TextServices::{ITfLangBarItemButton, ITfLangBarItemMgr},
};

use anyhow::Result;

#[derive(Default, Clone, PartialEq, Debug)]
pub enum InputMode {
    #[default]
    Latin,
    Kana,
}

impl TextServiceFactory {
    pub fn set_input_mode(&self, mode: &InputMode) -> Result<()> {
        // Do not hold IMEState across COM calls: GetIcon reads the same state.
        IMEState::get()?.input_mode = mode.clone();
        if let Err(error) = self.update_lang_bar() {
            tracing::warn!(?error, "Failed to refresh input mode icon");
        }

        let service = IMEState::get()?.ipc_service.clone();
        if let Some(mut service) = service {
            let label = match mode {
                InputMode::Latin => "A",
                InputMode::Kana => "あ",
            };
            if let Err(error) = service.set_input_mode(label) {
                tracing::warn!(?error, "Failed to display input mode indicator");
            }
        }
        Ok(())
    }

    pub fn update_lang_bar(&self) -> Result<()> {
        // change the icon of the language bar item
        let text_service = self.borrow()?;
        let thread_mgr = text_service.thread_mgr()?;

        unsafe {
            thread_mgr
                .cast::<ITfLangBarItemMgr>()?
                .RemoveItem(&text_service.this::<ITfLangBarItemButton>()?)?;

            thread_mgr
                .cast::<ITfLangBarItemMgr>()?
                .AddItem(&text_service.this::<ITfLangBarItemButton>()?)?;
        };

        Ok(())
    }
}

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity raw_mutrig_frame_top is
    port (
        i_clk            : in  std_logic;
        i_rst            : in  std_logic;
        i_start_trans    : in  std_logic;
        i_short_mode     : in  std_logic;
        i_gen_idle       : in  std_logic;
        i_offer_valid    : in  std_logic;
        i_offer_word     : in  std_logic_vector(47 downto 0);
        o_offer_ready    : out std_logic;
        o_accept_pulse   : out std_logic;
        o_fifo_rd_en     : out std_logic;
        o_event_count    : out std_logic_vector(9 downto 0);
        o_fifo_empty     : out std_logic;
        o_fifo_full      : out std_logic;
        o_fifo_almost_full : out std_logic;
        o_tx_data        : out std_logic_vector(8 downto 0);
        o_tx_valid       : out std_logic
    );
end entity raw_mutrig_frame_top;

architecture rtl of raw_mutrig_frame_top is
    signal s_fifo_dout        : std_logic_vector(47 downto 0);
    signal s_fifo_count       : std_logic_vector(7 downto 0);
    signal s_fifo_rd_en       : std_logic;
    signal s_fifo_dout_rdy    : std_logic;
    signal s_fifo_empty       : std_logic;
    signal s_fifo_full        : std_logic;
    signal s_fifo_almost_full : std_logic;
    signal s_fifo_write_en    : std_logic;
    signal s_fifo_write_act   : std_logic;
    signal s_offer_ready      : std_logic;
    signal s_accept_pulse_r   : std_logic;
    signal s_byte_isk         : std_logic;
    signal s_byte             : std_logic_vector(7 downto 0);
    signal s_tx_mode          : std_logic_vector(2 downto 0);
begin
    s_tx_mode <= "100" when i_short_mode = '1' else "000";

    s_offer_ready   <= (not s_fifo_full) or s_fifo_rd_en;
    s_fifo_write_en <= i_offer_valid and s_offer_ready;
    s_fifo_write_act <= i_offer_valid and (not s_fifo_full);
    o_offer_ready   <= s_offer_ready;
    o_accept_pulse  <= s_accept_pulse_r;
    o_event_count  <= "00" & s_fifo_count;
    o_fifo_rd_en   <= s_fifo_rd_en;
    o_fifo_empty   <= s_fifo_empty;
    o_fifo_full    <= s_fifo_full;
    o_fifo_almost_full <= s_fifo_almost_full;
    o_tx_data      <= s_byte_isk & s_byte;
    o_tx_valid     <= '1';

    p_accept_pulse : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_accept_pulse_r <= '0';
            else
                s_accept_pulse_r <= s_fifo_write_act;
            end if;
        end if;
    end process p_accept_pulse;

    u_l2_fifo : entity work.generic_dp_fifo
        generic map(
            C_DATA_WIDTH => 48,
            C_ADDR_WIDTH => 8,
            C_NUM_WORDS  => 256
        )
        port map(
            i_rst       => i_rst,
            clka        => i_clk,
            clkb        => i_clk,
            din         => i_offer_word,
            we_a        => s_fifo_write_en,
            re_b        => s_fifo_rd_en,
            dout        => s_fifo_dout,
            dout_rdy    => s_fifo_dout_rdy,
            count       => s_fifo_count,
            full        => s_fifo_full,
            empty       => s_fifo_empty,
            almost_full => s_fifo_almost_full
        );

    u_frame_gen : entity work.frame_gen
        generic map(
            IN_DATA_WIDTH     => 48,
            SHORT_DATA_WIDTH  => 28,
            N_BYTES_PER_WORD  => 6
        )
        port map(
            i_clk           => i_clk,
            i_rst           => i_rst,
            i_start_trans   => i_start_trans,
            i_fifo_full     => s_fifo_almost_full,
            o_fifo_rd_en    => s_fifo_rd_en,
            i_data          => s_fifo_dout,
            i_event_counts  => "00" & s_fifo_count,
            o_ready         => open,
            o_dbyteisk      => s_byte_isk,
            o_dbyte         => s_byte,
            i_enc_rdy       => '1',
            o_enc_rst       => open,
            i_SC_tx_mode    => s_tx_mode,
            i_SC_gen_idle_sig => i_gen_idle,
            i_HF_PLL_LOL    => '0',
            o_HF_read       => open
        );
end architecture rtl;

package org.traccar.protocol;

import org.junit.jupiter.api.Test;
import org.traccar.ProtocolTest;

public class MicodusProtocolDecoderTest extends ProtocolTest {

    @Test
    public void testDecode() throws Exception {

        var decoder = inject(new MicodusProtocolDecoder(null));

        verifyPosition(decoder, buffer(
                "*HQ,4209809058,V1,064709,V,2233.9355,N,11351.7442,E,000.00,000,231215,FFFFFBFF,460,00,0,0,6#"));
    }
}
